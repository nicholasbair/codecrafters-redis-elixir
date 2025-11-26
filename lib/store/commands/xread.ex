defmodule Server.Store.Commands.Xread do

  alias Server.{
    Request,
    Store.State,
  }

  @type entry_id :: {non_neg_integer(), non_neg_integer()} | non_neg_integer()

  @spec execute(Request.t(), State.record_state()) :: list()
  def execute(%Request{key: keys, value: ids}, state) do
    keys
    |> Enum.zip(ids)
    |> Enum.map(&xread(&1, state))
  end

  @spec xread(tuple(), State.record_state()) :: list()
  defp xread({key, id}, state) do
    start_time = parse_entry_id(id)

    state
    |> Map.get(key, %{})
    |> Map.get(:value, [])
    |> Enum.filter(&entry_match?(&1, start_time))
    |> Enum.reduce([], fn entry, acc -> acc ++ [key, [format_entry(entry)]] end)
  end

  @spec parse_entry_id(String.t()) :: entry_id()
  defp parse_entry_id(id) when is_bitstring(id) do
    id
    |> String.split("-")
    |> then(fn split ->
      case split do
        [t] -> String.to_integer(t)
        [t, s] -> {String.to_integer(t), String.to_integer(s)}
      end
    end)
  end

  @spec entry_match?(map(), entry_id()) :: boolean()
  defp entry_match?(%{entry_id: {time, seq}}, {start_time, start_seq}) do
    time > start_time or (time == start_time and seq > start_seq)
  end

  defp entry_match?(%{entry_id: {time, seq}}, start_time) do
    time > start_time or (time == start_time and seq > 0)
  end

  @spec format_entry(map()) :: list()
  defp format_entry(%{entry_id: {a, b}} = entry) do
    kv =
      entry
      |> Map.delete(:entry_id)
      |> Enum.into([], fn {k, v} -> [k, v] end)
      |> List.flatten()

    ["#{a}-#{b}", kv]
  end
end
