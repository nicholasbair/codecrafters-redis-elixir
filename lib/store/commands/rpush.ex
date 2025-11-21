defmodule Server.Store.Commands.Rpush do

  import Server.Store, only: [build_record: 1]
  alias Server.{
    Request,
    Store.Record,
  }

  @spec execute(Request.t(), map()) :: {non_neg_integer(), map()}
  def execute(%Request{key: key, value: value}, state) do
    case Map.get(state, key) do
      nil ->
        {length(value), Map.put(state, key, build_record(value))}
      %Record{value: existing} ->
        updated = existing ++ value
        {length(updated), Map.put(state, key, build_record(updated))}
    end
  end
end
