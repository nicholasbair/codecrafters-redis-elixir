defmodule Server.Store.Commands.Type do

  alias Server.{
    Request,
    Store.Record,
    Store.State
  }

  @spec execute(Request.t(), State.record_state()) :: Record.record_type() | nil
  def execute(%Request{key: key}, state) do
    case Map.get(state, key) do
      %Record{type: type} -> type
      _ -> nil
    end
  end
end
