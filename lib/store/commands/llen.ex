defmodule Server.Store.Commands.Llen do

  alias Server.{
    Request,
    Store.State
  }

  @spec execute(Request.t(), State.record_state()) :: integer()
  def execute(%Request{key: key}, state) do
    state
    |> Map.get(key, %{})
    |> Map.get(:value, [])
    |> length()
  end
end
