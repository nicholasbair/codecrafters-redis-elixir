defmodule Server.Store do

  use GenServer
  alias Server.{
    Message,
    Message.Options,
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

  def transaction(%Message{} = message) do
    GenServer.call(__MODULE__, message)
  end

  # Server

  def init(_) do
    schedule_expiry_check()
    {:ok, %{}}
  end

  def handle_call(%Message{command: "SET", key: k, value: v, options: opt}, _from, state) do
    new_state = Map.put(state, k, build_record(v, opt))
    {:reply, :ok, new_state}
  end

  def handle_call(%Message{command: cmd, key: k, value: v}, _from, state) when cmd in ["RPUSH", "LPUSH"] do
    case Map.get(state, k) do
      nil ->
        {:reply, {:ok, length(v)}, Map.put(state, k, build_record(v))}
      %Record{value: val} ->
        updated = add_to_list(val, v, cmd)
        {:reply, {:ok, length(val) + length(v)}, Map.put(state, k, build_record(updated))}
    end
  end

  def handle_call(%Message{command: "LPOP", key: k}, _from, state) do
    val =
      state
      |> Map.get(k, %{})
      |> Map.get(:value, [])
      |> maybe_get_first()

    {:reply, {:ok, val}, state}
  end

  def handle_call(%Message{command: "LLEN", key: k}, _from, state) do
    val =
      state
      |> Map.get(k, %{})
      |> Map.get(:value, [])
      |> length()

    {:reply, {:ok, val}, state}
  end

  def handle_call(%Message{command: "LRANGE", key: k, value: [s, e]}, _from, state) do
    val =
      state
      |> Map.get(k, %{})
      |> Map.get(:value, [])
      |> maybe_slice_list(s, e)

    {:reply, {:ok, val}, state}
  end

  def handle_call(%Message{command: "GET", key: k}, _from, state) do
    case get_value(state, k) do
      :expired ->
        {:reply, {:ok, nil}, Map.delete(state, k)}
      nil ->
        {:reply, {:ok, nil}, state}
      %Record{value: val} ->
        {:reply, {:ok, val}, state}
    end
  end

  def handle_call(%Message{}, _from, state) do
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
  defp build_record(value, opt \\ nil)
  defp build_record(value, nil), do: %Record{value: value}

  defp build_record(value, %{ttl_ms: ttl}) do
    %Record{value: value, expire_at: now() + ttl}
  end

  defp build_record(value, %{expire_at_ms: time}) do
    %Record{value: value, expire_at: time}
  end

  @spec get_value(map(), String.t()) :: Record.t() | :expired | nil
  defp get_value(state, key) do
    state
    |> Map.get(key)
    |> check_expiry()
  end

  @spec check_expiry(Record.t()) :: Record.t() | :expired | nil
  defp check_expiry(%Record{expire_at: nil} = record), do: record
  defp check_expiry(%Record{expire_at: expiry} = record) do
    case expiry < now() do
      true -> :expired
      false -> record
    end
  end
  defp check_expiry(nil), do: nil

  defp now() do
    DateTime.utc_now()
    |> DateTime.to_unix(:millisecond)
  end

  defp schedule_expiry_check() do
    Process.send_after(self(), :purge_expired, @purged_expired_interval)
  end

  @spec maybe_slice_list(list(), integer(), integer()) :: list()
  defp maybe_slice_list([], _first, _last), do: []
  defp maybe_slice_list(_list, first, last) when first > last and last > 0, do: []
  defp maybe_slice_list(list, first, last) when first > last do
    Enum.slice(list, first..last//1)
  end
  defp maybe_slice_list(list, first, last), do: Enum.slice(list, first..last)

  @spec add_to_list(list(), list(), String.t()) :: list()
  defp add_to_list(existing, new, "RPUSH"), do: existing ++ new
  defp add_to_list(existing, new, "LPUSH"), do: new ++ existing

  @spec maybe_get_first(list()) :: nil | String.t()
  defp maybe_get_first([]), do: nil
  defp maybe_get_first([hd | _tl]), do: hd
end
