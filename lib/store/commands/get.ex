defmodule Server.Store.Commands.Get do

  alias Server.{
    Request,
    Store.Record,
    Util
  }

  @spec execute(Request.t(), map()) :: {any(), map()}
  def execute(%Request{key: key}, state) do
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

  # TODO: consolidate with Store.expired?/1
  @spec check_expiry(Record.t()) :: Record.t() | :expired | nil
  defp check_expiry(%Record{expire_at: nil} = record), do: record
  defp check_expiry(%Record{expire_at: expiry} = record) do
    case expiry < Util.now() do
      true -> :expired
      false -> record
    end
  end
  defp check_expiry(nil), do: nil
end
