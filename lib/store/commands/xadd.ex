defmodule Server.Store.Commands.Xadd do

  alias Server.{
    Request,
    Store.Record,
    Store.State
  }

  @spec execute(Request.t(), State.record_state()) :: {entry_id :: String.t(), State.record_state()}
  def execute(%Request{key: key, value: value}, state) do
    new_record_state =
      Map.update(state, key, %Record{value: [], type: :stream}, fn existing ->
        %{existing | value: existing.value ++ [value]}
      end)

    {value.entry_id, new_record_state}
  end
end
