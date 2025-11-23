defmodule Server.Store.Commands.Xadd do

  alias Server.{
    Request,
    Store.Record,
    Store.State,
    Util
  }

  @type entry_id :: {non_neg_integer() | String.t(), non_neg_integer() | String.t()} | String.t()

  @spec execute(Request.t(), State.record_state()) :: {:ok, String.t(), State.record_state()} | {:error, String.t()}
  def execute(%Request{key: key, value: value}, state) do
    entry_id = parse_entry_id(value.entry_id)
    existing_record = Map.get(state, key)

    case validate_or_generate_entry_id(existing_record, entry_id) do
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
  defp parse_entry_id("*"), do: "*"
  defp parse_entry_id(id) when is_bitstring(id) do
    id
    |> String.split("-")
    |> then(fn [t, s] -> {maybe_to_integer(t), maybe_to_integer(s)} end)
  end

  @spec entry_id_to_string(entry_id()) :: String.t()
  defp entry_id_to_string({a, b}), do: "#{a}-#{b}"

  @spec validate_or_generate_entry_id(Record.t() | nil, entry_id()) :: {:ok, entry_id()} | {:error, String.t()}
  defp validate_or_generate_entry_id(_previous, {0, 0}), do: {:error, "The ID specified in XADD must be greater than 0-0"}

  # Auto-generate sequence number
  defp validate_or_generate_entry_id(nil, {0, "*"}), do: {:ok, {0, 1}}
  defp validate_or_generate_entry_id(nil, {t, "*"}), do: {:ok, {t, 0}}
  defp validate_or_generate_entry_id(%Record{value: []}, {0, "*"}), do: {:ok, {0, 1}}
  defp validate_or_generate_entry_id(%Record{value: []}, {t, "*"}), do: {:ok, {t, 0}}
  defp validate_or_generate_entry_id(%Record{value: val}, {new_time, "*"}) do
    {prev_time, prev_sequence} =
      val
      |> List.last()
      |> Map.get(:entry_id)

    cond do
      prev_time < new_time -> {:ok, {new_time, 0}}
      prev_time == new_time -> {:ok, {new_time, prev_sequence + 1}}
      prev_time > new_time -> {:error, "The ID specified in XADD is equal or smaller than the target stream top item"}
    end
  end

  # Auto-generate entire ID
  defp validate_or_generate_entry_id(nil, "*"), do: {:ok, {Util.now, 0}}
  defp validate_or_generate_entry_id(%Record{value: []}, "*"), do: {:ok, {Util.now, 0}}
  defp validate_or_generate_entry_id(%Record{value: val}, "*") do
    {prev_time, prev_sequence} =
      val
      |> List.last()
      |> Map.get(:entry_id)

    now = Util.now()

    cond do
      prev_time == now -> {:ok, {now, prev_sequence + 1}}
      true -> {:ok, {now, 0}}
    end
  end

  # Caller provided ID
  defp validate_or_generate_entry_id(%Record{value: []}, new), do: {:ok, new}
  defp validate_or_generate_entry_id(nil, new), do: {:ok, new}
  defp validate_or_generate_entry_id(%Record{value: val}, {new_time, new_sequence} = new) do
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

  @spec maybe_to_integer(String.t()) :: non_neg_integer() | String.t()
  defp maybe_to_integer("*"), do: "*"
  defp maybe_to_integer(val), do: String.to_integer(val)
end
