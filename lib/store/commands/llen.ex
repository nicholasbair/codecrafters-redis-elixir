defmodule Server.Store.Commands.Llen do

  @spec execute(String.t(), map()) :: integer()
  def execute(key, state) do
    state
    |> Map.get(key, %{})
    |> Map.get(:value, [])
    |> length()
  end
end
