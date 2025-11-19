defmodule Server.Store.Commands.Lpop do

  alias Server.Store.Record

  @spec execute(String.t(), integer() | nil, map()) :: {any(), map()}
  def execute(key, nil, state), do: execute(key, 1, state)

  # Lpop takes an optional number of items to remove from list
  def execute(key, count, state) do
    case record = Map.get(state, key, nil) do
      %Record{value: value} ->
        {val, rest} = Enum.split(value, count)
        {maybe_unwrap(val), Map.put(state, key, %{record | value: rest})}

      nil ->
        {nil, state}
    end
  end

  @spec maybe_unwrap(list()) :: nil | String.t() | integer() | list()
  defp maybe_unwrap([]), do: nil
  defp maybe_unwrap([val]), do: val
  defp maybe_unwrap(val), do: val
end
