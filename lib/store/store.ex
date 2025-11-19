defmodule Server.Store do

  use GenServer
  alias Server.{
    Request,
    Request.Options,
    Store.Commands,
    Store.Record
  }

  @purged_expired_interval 30_000

  defmodule Record do
    @type t :: %__MODULE__{
      value: String.t() | list() | nil,
      expire_at: integer() | nil
    }

    defstruct [
      :value,
      :expire_at
    ]
  end

  # TODO: handle other options, only expirations are implemented here

  # Client

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def transaction(%Request{} = req), do: GenServer.call(__MODULE__, req)

  # Server

  def init(_) do
    schedule_expiry_check()
    {:ok, %{}}
  end

  def handle_call(%Request{command: "SET", key: k, value: v, options: opt}, _from, state) do
    new_state = Commands.Set.execute(k, v, opt, state)
    {:reply, :ok, new_state}
  end

  def handle_call(%Request{command: "RPUSH", key: k, value: v}, _from, state) do
    {n, new_state} = Commands.Rpush.execute(k, v, state)
    {:reply, {:ok, n}, new_state}
  end

  def handle_call(%Request{command: "LPUSH", key: k, value: v}, _from, state) do
    {n, new_state} = Commands.Lpush.execute(k, v, state)
    {:reply, {:ok, n}, new_state}
  end

  def handle_call(%Request{command: "LPOP", key: k, value: v}, _from, state) do
    {val, new_state} = Commands.Lpop.execute(k, v, state)
    {:reply, {:ok, val}, new_state}
  end

  def handle_call(%Request{command: "LLEN", key: k}, _from, state) do
    val = Commands.Llen.execute(k, state)
    {:reply, {:ok, val}, state}
  end

  def handle_call(%Request{command: "LRANGE", key: k, value: [s, e]}, _from, state) do
    val = Commands.Lrange.execute(k, s, e, state)
    {:reply, {:ok, val}, state}
  end

  def handle_call(%Request{command: "GET", key: k}, _from, state) do
    {val, new_state} = Commands.Get.execute(k, state)
    {:reply, {:ok, val}, new_state}
  end

  def handle_call(%Request{}, _from, state) do
    {:reply, {:error, :unhandled_command}, state}
  end

  def handle_info(:purge_expired, state) do
    updated_state =
      Enum.reduce(state, %{}, fn {k, v}, acc ->
        case check_expiry(v) do
          %Record{} -> Map.put(acc, k, v)
          _ -> acc
        end
      end)

    schedule_expiry_check()

    {:noreply, updated_state}
  end

  @spec build_record(any(), Options.t() | nil) :: Record.t()
  def build_record(value, opt \\ nil)
  def build_record(value, nil), do: %Record{value: value}

  def build_record(value, %{ttl_ms: ttl}) do
    %Record{value: value, expire_at: now() + ttl}
  end

  def build_record(value, %{expire_at_ms: time}) do
    %Record{value: value, expire_at: time}
  end

  def now() do
    DateTime.utc_now()
    |> DateTime.to_unix(:millisecond)
  end

  @spec check_expiry(Record.t()) :: Record.t() | :expired | nil
  def check_expiry(%Record{expire_at: nil} = record), do: record
  def check_expiry(%Record{expire_at: expiry} = record) do
    case expiry < now() do
      true -> :expired
      false -> record
    end
  end
  def check_expiry(nil), do: nil

  defp schedule_expiry_check() do
    Process.send_after(self(), :purge_expired, @purged_expired_interval)
  end
end
