defmodule Server.Store.Commands.Xrange do

  alias Server.{
    Request,
    Store.State,
  }

  @type entry_id :: {non_neg_integer(), non_neg_integer()} | non_neg_integer() | String.t()

  @spec execute(Request.t(), State.record_state()) :: list()
  def execute(%Request{key: key, value: {s, e}}, state) do
    start_time = parse_entry_id(s)
    end_time = parse_entry_id(e)

    state
    |> Map.get(key, %{})
    |> Map.get(:value, [])
    |> Enum.filter(&entry_match?(&1, start_time, end_time))
    |> Enum.reduce([], fn entry, acc -> acc ++ [format_entry(entry)] end)
  end

  @spec parse_entry_id(String.t()) :: entry_id()
  defp parse_entry_id("-"), do: "-"
  defp parse_entry_id("+"), do: "+"
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

  @spec entry_match?(map(), entry_id(), entry_id()) :: boolean()
  defp entry_match?(%{entry_id: {time, seq}}, "-", {end_time, end_seq}) do
    time <= end_time and seq <= end_seq
  end

  defp entry_match?(%{entry_id: {time, _seq}}, "-", end_time) do
    time <= end_time
  end

  defp entry_match?(%{entry_id: {time, seq}}, {start_time, start_seq}, "+") do
    time >= start_time and seq >= start_seq
  end

  defp entry_match?(%{entry_id: {time, _seq}}, start_time, "+") do
    time >= start_time
  end

  defp entry_match?(%{entry_id: {time, seq}}, {start_time, start_seq}, {end_time, end_seq}) do
    time >= start_time and seq >= start_seq and time <= end_time and seq <= end_seq
  end

  defp entry_match?(%{entry_id: {time, seq}}, {start_time, start_seq}, end_time) do
    time >= start_time and seq >= start_seq and time <= end_time
  end

  defp entry_match?(%{entry_id: {time, seq}}, start_time, {end_time, end_seq}) do
    time >= start_time and seq >= 0 and time <= end_time and seq <= end_seq
  end

  defp entry_match?(%{entry_id: {time, seq}}, start_time, end_time) do
    time >= start_time and seq >= 0 and time <= end_time
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
