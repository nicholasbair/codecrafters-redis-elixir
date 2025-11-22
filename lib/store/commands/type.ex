defmodule Server.Store.Commands.Type do

  alias Server.{
    Request,
    Store.Record,
  }

  @spec execute(Request.t(), map()) :: atom() | nil
  def execute(%Request{key: key}, state) do
    case Map.get(state, key) do
      %Record{type: type} -> type
      _ -> nil
    end
  end
end
