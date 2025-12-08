defmodule Server.Store.Commands.Incr do

  alias Server.{
    Request,
    Store,
    Store.Record,
    Store.State
  }

  @spec execute(Request.t(), State.record_state()) :: {non_neg_integer(), State.record_state()}
  def execute(%Request{key: key}, state) do
    case Map.get(state, key) do
      nil ->
        {1, Map.put(state, key, Store.build_record(1, :integer))}
      %Record{value: existing} = record ->
        updated = %{record | value: increment(existing)}
        {updated.value, Map.put(state, key, updated)}
    end
  end

  # SET initially stores the value as a string
  defp increment(val) when is_bitstring(val), do: String.to_integer(val) + 1
  defp increment(val) when is_integer(val), do: val + 1
end
