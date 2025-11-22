defmodule Server.Store.Commands.Lrange do

  alias Server.{
    Request,
    Store.Record,
    Store.State
  }

  @spec execute(Request.t(), State.record_state()) :: [Record.t()]
  def execute(%Request{key: k, value: [from, to]}, state) do
    state
    |> Map.get(k, %{})
    |> Map.get(:value, [])
    |> maybe_slice_list(from, to)
  end

  @spec maybe_slice_list(list(), integer(), integer()) :: list()
  defp maybe_slice_list([], _first, _last), do: []
  defp maybe_slice_list(_list, first, last) when first > last and last > 0, do: []
  defp maybe_slice_list(list, first, last) when first > last do
    Enum.slice(list, first..last//1)
  end
  defp maybe_slice_list(list, first, last), do: Enum.slice(list, first..last)
end
