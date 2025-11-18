defmodule Server.Encoder do

  alias Server.Message

  @crlf "\r\n"

  @spec encode(Message.t()) :: String.t()
  def encode(%Message{reply: {:simple, val}}) when is_bitstring(val), do: "+#{val}#{@crlf}"
  def encode(%Message{reply: {:simple, val}}) when is_integer(val), do: ":#{val}#{@crlf}"

  def encode(%Message{reply: {:bulk, nil}}), do: "$-1" <> @crlf

  def encode(%Message{reply: {:bulk, val}}) when is_bitstring(val) do
    encode_item(val)
  end

  def encode(%Message{reply: {:bulk, val}}) when is_list(val) do
    "*#{length(val)}" <> @crlf <> encode_items(val)
  end

  @spec encode_items([String.t()]) :: String.t()
  defp encode_items(items) when is_list(items) do
    Enum.reduce(items, "", fn i, acc -> acc <> encode_item(i) end)
  end

  defp encode_item(item) when is_bitstring(item) do
    "$#{String.length(item)}" <> @crlf <> item <> @crlf
  end
end
