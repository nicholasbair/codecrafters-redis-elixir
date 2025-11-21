defmodule Server.Store.Commands.Llen do

  alias Server.{
    Request,
  }

  @spec execute(Request.t(), map()) :: integer()
  def execute(%Request{key: key}, state) do
    state
    |> Map.get(key, %{})
    |> Map.get(:value, [])
    |> length()
  end
end
