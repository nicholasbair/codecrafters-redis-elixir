defmodule Server.Store do

  use GenServer
  alias Server.{
    Request,
    Request.Options,
    State,
    Store.BlockedCaller,
    Store.Commands,
    Store.Record,
    Util
  }

  @purge_expired_keys_interval 5_000
  @purge_expired_blocked_interval 1_000

  defmodule State do
    @type t :: %__MODULE__{
      records: record_state(),
      blocked: blocked_state()
    }

    @type record_state :: %{String.t() => Record.t()}
    @type blocked_state :: %{String.t() => [BlockedCaller.t()]}

    defstruct [
      blocked: %{},
      records: %{}
    ]
  end

  defmodule Record do
    @type t :: %__MODULE__{
      value: String.t() | list() | nil,
      expire_at: integer() | nil,
      type: record_type() | nil
    }

    @type record_type :: :string | :list | :set | :zset | :hash | :stream | :vectorset

    @enforce_keys [:value]
    defstruct [:value, :expire_at, :type]
  end

  defmodule BlockedCaller do
    @type t :: %__MODULE__{
      from: from(),
      expire_at: expire_at(),
      original_request: Request.t() | nil
    }

    @type from() :: {pid(), tag :: term()}
    @type expire_at :: non_neg_integer() | :infinity

    @enforce_keys [:from, :expire_at]
    defstruct [:from, :expire_at, :original_request]
  end

  # Client

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec transaction(Request.t()) :: :ok | {:ok, any()} | {:error, String.t() | atom()}
  # BLPOP is blocking, use infinity for the call and delegate actual timeout downstream
  def transaction(%Request{command: "BLPOP"} = req), do: GenServer.call(__MODULE__, req, :infinity)
  def transaction(%Request{} = req), do: GenServer.call(__MODULE__, req)

  # Server

  def init(_) do
    schedule_key_expiry_check()
    schedule_blocked_expiry_check()
    {:ok, %State{}}
  end

  # TODO: handle other SET options, only expirations are implemented here
  def handle_call(%Request{command: "SET"} = req, _from, state) do
    new_state =
      req
      |> Commands.Set.execute(state.records)
      |> then(fn records -> %{state | records: records} end)
      |> handle_unblock(req, "SET")

    {:reply, :ok, new_state}
  end

  def handle_call(%Request{command: "RPUSH"} = req, _from, state) do
    {n, new_record_state} = Commands.Rpush.execute(req, state.records)
    new_state = handle_unblock(%{state | records: new_record_state}, req, "RPUSH")

    {:reply, {:ok, n}, new_state}
  end

  def handle_call(%Request{command: "LPUSH"} = req, _from, state) do
    {n, new_record_state} = Commands.Lpush.execute(req, state.records)
    new_state = handle_unblock(%{state | records: new_record_state}, req, "LPUSH")

    {:reply, {:ok, n}, new_state}
  end

  def handle_call(%Request{command: "LPOP"} = req, _from, state) do
    {val, new_state} = Commands.Lpop.execute(req, state.records)
    {:reply, {:ok, val}, %{state | records: new_state}}
  end

  def handle_call(%Request{command: "BLPOP"} = req, from, state) do
    case Commands.Blpop.execute(req, state.records) do
      {:block, _state} ->
        new_caller = [%BlockedCaller{from: from, expire_at: build_expiry(req.options.timeout)}]
        new_blocked_state =
          Enum.reduce(req.key, state.blocked, fn key, blocked_map ->
            # BLPOP req.key is a list of keys
            Map.update(blocked_map, key, new_caller, fn existing ->
              existing ++ new_caller
            end)
          end)

        {:noreply, %{state | blocked: new_blocked_state}}

      {val, new_state} ->
        {:reply, {:ok, val}, %{state | records: new_state}}
    end
  end

  def handle_call(%Request{command: "LLEN"} = req, _from, state) do
    val = Commands.Llen.execute(req, state.records)
    {:reply, {:ok, val}, state}
  end

  def handle_call(%Request{command: "LRANGE"} = req, _from, state) do
    val = Commands.Lrange.execute(req, state.records)
    {:reply, {:ok, val}, state}
  end

  def handle_call(%Request{command: "GET"} = req, _from, state) do
    {val, new_state} = Commands.Get.execute(req, state.records)
    {:reply, {:ok, val}, %{state | records: new_state}}
  end

  def handle_call(%Request{command: "TYPE"} = req, _from, state) do
    val = Commands.Type.execute(req, state.records)
    {:reply, {:ok, val}, state}
  end

  def handle_call(%Request{command: "XADD"} = req, _from, state) do
    case Commands.Xadd.execute(req, state.records) do
      {:ok, entry_id, new_record_state} ->
        new_state = handle_unblock(%{state | records: new_record_state}, req, "XADD")
        {:reply, {:ok, entry_id}, new_state}
      {:error, err} ->
        {:reply, {:error, err}, state}
    end
  end

  def handle_call(%Request{command: "XRANGE"} = req, _from, state) do
    records = Commands.Xrange.execute(req, state.records)
    {:reply, {:ok, records}, state}
  end

  # TODO: need to add block check on XADD
  def handle_call(%Request{command: "XREAD"} = req, from, state) do
    case Commands.Xread.execute(req, state.records) do
      {:ok, records} -> {:reply, {:ok, records}, state}
      :block ->
        new_caller = [
          %BlockedCaller{
            from: from,
            expire_at: build_expiry(req.options.timeout),
            original_request: req
          }
        ]

        new_blocked_state =
          Enum.reduce(req.key, state.blocked, fn key, blocked_map ->
            # XREAD req.key is a list of keys
            Map.update(blocked_map, key, new_caller, fn existing ->
              existing ++ new_caller
            end)
          end)

        {:noreply, %{state | blocked: new_blocked_state}}
    end
  end

  def handle_call(%Request{}, _from, state) do
    {:reply, {:error, :unhandled_command}, state}
  end

  def handle_info(:purge_expired_keys, state) do
    new_record_state =
      Enum.reduce(state.records, %{}, fn {k, v}, acc ->
        case expired?(v.expire_at) do
          true -> acc
          false -> Map.put(acc, k, v)
        end
      end)

    schedule_key_expiry_check()

    {:noreply, %{state | records: new_record_state}}
  end

  def handle_info(:purge_expired_blocked, state) do
    %{still_blocked: new_blocked_state, expired: expired} =
      Enum.reduce(state.blocked, %{still_blocked: %{}, expired: []}, fn {k, v}, acc ->
        {expired, not_expired} = Enum.split_with(v, fn v -> expired?(v.expire_at) end)
        blocked = Map.put(acc.still_blocked, k, not_expired)

        %{acc | still_blocked: blocked, expired: acc.expired ++ expired}
      end)

    for e <- expired, do: GenServer.reply(e.from, {:ok, nil})

    schedule_blocked_expiry_check()

    {:noreply, %{state | blocked: new_blocked_state}}
  end

  @spec build_record(any(), atom()) :: Record.t()
  def build_record(value, type), do: %Record{value: value, type: type}

  @spec expired?(BlockedCaller.expire_at()) :: boolean()
  defp expired?(:infinity), do: false
  defp expired?(expiry), do: expiry < Util.now()

  defp schedule_key_expiry_check() do
    Process.send_after(
      self(),
      :purge_expired_keys,
      @purge_expired_keys_interval
    )
  end

  defp schedule_blocked_expiry_check() do
    Process.send_after(
      self(),
      :purge_expired_blocked,
      @purge_expired_blocked_interval
    )
  end

  @spec handle_unblock(State.t(), Request.t(), String.t()) :: State.t()
  defp handle_unblock(state, req, trigger) do
    case Map.get(state.blocked, req.key) do
      nil -> state
      [] -> state
      blocked_list ->
        {expired, not_expired} = Enum.split_with(blocked_list, fn b -> expired?(b.expire_at) end)
        for e <- expired, do: GenServer.reply(e.from, {:ok, nil})
        find_and_reply(not_expired, req, state, trigger)
    end
  end

  # TODO: this assumes only one actionable blocked caller
  @spec find_and_reply([BlockedCaller.t()], Request.t(), State.t(), String.t()) :: State.t()
  defp find_and_reply([caller | tl] = blocked_list, req, state, trigger) when trigger in ["SET", "RPUSH", "LPUSH"] do
    req = %Request{key: req.key}
    case Commands.Lpop.execute(req, state.records) do
      {nil, _} ->
        %{state | blocked: Map.put(state.blocked, req.key, blocked_list)}

      {val, updated_state} ->
        GenServer.reply(caller.from, {:ok, [req.key, val]})
        %{state | records: updated_state, blocked: maybe_update_blocked(state.blocked, req.key, tl)}
    end
  end

  defp find_and_reply([caller | tl] = blocked_list, _req, state, "XADD") do
    req = Map.delete(caller.original_request, :options)
    case Commands.Xread.execute(req, state.records) do
      {:ok, []} ->
        %{state | blocked: Map.put(state.blocked, req.key, blocked_list)}

      {:ok, results} ->
        GenServer.reply(caller.from, {:ok, results})
        %{state | blocked: maybe_update_blocked(state.blocked, req.key, tl)}
    end
  end

  defp find_and_reply([] = _blocked_list, request, state, _trigger) do
    %{state | blocked: Map.delete(state.blocked, request.key)}
  end

  @spec maybe_update_blocked(State.blocked_state(), String.t(), list()) :: State.blocked_state()
  defp maybe_update_blocked(blocked_state, key, []), do: Map.delete(blocked_state, key)
  defp maybe_update_blocked(blocked_state, key, blocked), do: Map.put(blocked_state, key, blocked)

  @spec build_expiry(BlockedCaller.expire_at()) :: non_neg_integer()
  defp build_expiry(:infinity), do: :infinity
  defp build_expiry(timeout), do: Util.now() + timeout
end
