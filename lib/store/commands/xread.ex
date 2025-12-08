defmodule Server.Store.Commands.Xread do

  alias Server.{
    Request,
    Store.State,
  }

  @type entry_id :: {non_neg_integer(), non_neg_integer()} | non_neg_integer()
  @type block :: {:block, entry_id()} | :block

  @spec execute(Request.t(), State.record_state()) :: {:ok, list()} | block()
  # TODO: assumes a single $, but can be a list of multiple $ or mixed
  def execute(%Request{key: [key], value: ["$"], options: %{block?: true}}, state) do
    last_id =
      state
      |> get_value(key)
      |> List.last(%{})
      |> Map.get(:entry_id, 0)

    {:block, last_id}
  end

  def execute(%Request{key: keys, value: ids, options: %{block?: true}}, state) do
    results =
      keys
      |> Enum.zip(ids)
      |> Enum.map(&xread(&1, state))
      |> format_results()

    case results do
      [] -> :block
      _ -> {:ok, results}
    end
  end

  def execute(%Request{key: keys, value: ids}, state) do
    keys
    |> Enum.zip(ids)
    |> Enum.map(&xread(&1, state))
    |> format_results()
    |> then(fn results -> {:ok, results} end)
  end

  @spec xread(tuple(), State.record_state()) :: list()
  defp xread({key, id}, state) do
    start_time = parse_entry_id(id)

    state
    |> get_value(key)
    |> Enum.filter(&entry_match?(&1, start_time))
    |> Enum.reduce([], fn entry, acc -> acc ++ [key, [format_entry(entry)]] end)
  end

  @spec get_value(State.record_state(), non_neg_integer()) :: list()
  defp get_value(state, key) do
    state
    |> Map.get(key, %{})
    |> Map.get(:value, [])
  end

  @spec format_results(list()) :: list()
  defp format_results([[]]), do: []
  defp format_results(results), do: results

  @spec parse_entry_id(String.t() | integer() | tuple()) :: entry_id()
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

  defp parse_entry_id(id) when is_integer(id), do: {id, 0}
  defp parse_entry_id({a, b} = id) when is_integer(a) and is_integer(b), do: id

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
