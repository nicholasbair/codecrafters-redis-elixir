defmodule Server.Store.Commands.Lpush do

  import Server.Store, only: [build_record: 2]
  alias Server.{
    Request,
    Store.Record,
    Store.State
  }

  @spec execute(Request.t(), State.record_state()) :: {non_neg_integer(), State.record_state()}
  def execute(%Request{key: key, value: value}, state) do
    case Map.get(state, key) do
      nil ->
        {length(value), Map.put(state, key, build_record(value, :list))}
      %Record{value: existing} ->
        updated = value ++ existing
        {length(updated), Map.put(state, key, build_record(updated, :list))}
    end
  end
end
