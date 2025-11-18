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

  def handle_call(%Message{command: "RPUSH", key: k, value: v}, _from, state) do
    case Map.get(state, k) do
      nil ->
        {:reply, {:ok, length(v)}, Map.put(state, k, build_record(v))}
      %Record{value: val} ->
        {:reply, {:ok, length(val) + length(v)}, Map.put(state, k, build_record(val ++ v))}
    end
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
end
