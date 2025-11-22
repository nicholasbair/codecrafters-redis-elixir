defmodule Server.Store.Commands.Lpop do

  alias Server.{
    Request,
    Store.Record,
    Store.State
  }

  @spec execute(Request.t(), State.record_state()) :: {any(), State.record_state()}
  def execute(%Request{key: key, value: count}, state) do
    # Lpop takes an optional number of items to remove from list
    count = count || 1

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
