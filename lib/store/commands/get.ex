defmodule Server.Store.Commands.Get do

  alias Server.Store.Record
  import Server.Store, only: [check_expiry: 1]

  @spec execute(String.t(), map()) :: {any(), map()}
  def execute(key, state) do
    case get_value(state, key) do
      :expired ->
        {nil, Map.delete(state, key)}
      nil ->
        {nil, state}
      %Record{value: val} ->
        {val, state}
    end
  end

  @spec get_value(map(), String.t()) :: Record.t() | :expired | nil
  defp get_value(state, key) do
    state
    |> Map.get(key)
    |> check_expiry()
  end
end
