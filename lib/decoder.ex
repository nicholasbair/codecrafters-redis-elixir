defmodule Server.Decoder do

  alias Server.Message

  @crlf "\r\n"

  @spec decode(Message.t()) :: Message.t()
  def decode(%Message{raw: raw} = message) do
    [elements | rest] = String.split(raw, @crlf)
    num_elements = parse_num_elements(elements)

    rest
    |> Enum.chunk_every(2)
    |> Enum.take(num_elements)
    |> Enum.map(&parse_chunk/1)
    |> List.to_tuple()
    |> into_message(message)
  end

  @spec parse_num_elements(String.t()) :: non_neg_integer()
  defp parse_num_elements(elements) do
    elements
    |> String.split_at(1)
    |> then(fn {_, n} -> String.to_integer(n) end)
  end

  # TODO: prob will need to parse head of list at some point
  @spec parse_chunk([String.t()]) :: String.t()
  defp parse_chunk([_type, val]), do: val

  @spec into_message(tuple(), Message.t()) :: Message.t()
  defp into_message({cmd, val}, message), do: %{message | command: cmd, value: val}
  defp into_message({cmd}, message), do: %{message | command: cmd}
end
