defmodule Server.Store.Commands.Rpush do

  import Server.Store, only: [build_record: 1]
  alias Server.Store.Record

  @spec execute(String.t(), any(), map()) :: {non_neg_integer(), map()}
  def execute(key, value, state) do
    case Map.get(state, key) do
      nil ->
        {length(value), Map.put(state, key, build_record(value))}
      %Record{value: existing} ->
        updated = existing ++ value
        {length(updated), Map.put(state, key, build_record(updated))}
    end
  end
end
