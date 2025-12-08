defmodule Server.Store.Commands.Incr do

  alias Server.{
    Request,
    Store,
    Store.Record,
    Store.State
  }

  @spec execute(Request.t(), State.record_state()) ::
    {:ok, non_neg_integer(), State.record_state()} |
    {:error, String.t(), State.record_state()}
  def execute(%Request{key: key}, state) do
    case Map.get(state, key) do
      nil ->
        {:ok, 1, Map.put(state, key, Store.build_record("1", :string))}

      %Record{value: existing} = record ->
        case increment(existing) do
          :error ->
            {:error, "value is not an integer or out of range", state}
          incremented ->
            {:ok, incremented, Map.put(state, key, %{record | value: to_string(incremented)})}
        end
    end
  end

  @spec increment(integer() | String.t()) :: integer() | :error
  defp increment(val) when is_integer(val), do: val + 1
  defp increment(val) when is_bitstring(val) do
    case Integer.parse(val) do
      {int, _} -> int + 1
      :error -> :error
    end
  end
end
