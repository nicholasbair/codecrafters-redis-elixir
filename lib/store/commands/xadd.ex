defmodule Server.Store.Commands.Xadd do

  alias Server.{
    Request,
    Store.Record,
    Store.State
  }

  @type entry_id :: {non_neg_integer(), non_neg_integer()}

  @spec execute(Request.t(), State.record_state()) :: {:ok, String.t(), State.record_state()} | {:error, String.t()}
  def execute(%Request{key: key, value: value}, state) do
    entry_id = parse_entry_id(value.entry_id)
    existing_record = Map.get(state, key)

    case validate_entry_id(existing_record, entry_id) do
      {:ok, validated_id} ->
        new_value = %{value | entry_id: validated_id}
        updated_record = build_or_update_record(existing_record, new_value)
        {:ok, entry_id_to_string(validated_id), Map.put(state, key, updated_record)}

      {:error, _msg} = err -> err
    end
  end

  defp build_or_update_record(nil, new_value) do
    %Record{type: :stream, value: [new_value]}
  end

  defp build_or_update_record(%Record{} = record, new_value) do
    %{record | value: record.value ++ [new_value]}
  end

  @spec parse_entry_id(String.t()) :: entry_id()
  defp parse_entry_id(id) when is_bitstring(id) do
    id
    |> String.split("-")
    |> then(fn [t, s] -> {String.to_integer(t), String.to_integer(s)} end)
  end

  @spec entry_id_to_string(entry_id()) :: String.t()
  defp entry_id_to_string({a, b}), do: "#{a}-#{b}"

  @spec validate_entry_id(Record.t() | nil, entry_id()) :: {:ok, entry_id()} | {:error, String.t()}
  defp validate_entry_id(_previous, {0, 0}), do: {:error, "The ID specified in XADD must be greater than 0-0"}
  defp validate_entry_id(nil, new), do: {:ok, new}
  defp validate_entry_id(%Record{value: []}, new), do: {:ok, new}
  defp validate_entry_id(%Record{value: val}, {new_time, new_sequence} = new) do
    {prev_time, prev_sequence} =
      val
      |> List.last()
      |> Map.get(:entry_id)

    cond do
      prev_time < new_time -> {:ok, new}
      prev_time == new_time and prev_sequence < new_sequence -> {:ok, new}
      true -> {:error, "The ID specified in XADD is equal or smaller than the target stream top item"}
    end
  end
end
