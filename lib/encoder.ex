defmodule Server.Encoder do

  alias Server.Connection

  @crlf "\r\n"

  @spec encode(Connection.t()) :: String.t()
  def encode(%Connection{response: %{type: :simple, value: val}}) when is_bitstring(val) do
    "+#{val}#{@crlf}"
  end

  def encode(%Connection{response: %{type: :simple, value: val}}) when is_integer(val) do
    ":#{val}#{@crlf}"
  end

  def encode(%Connection{response: %{type: :bulk, value: nil}}), do: "$-1" <> @crlf

  def encode(%Connection{response: %{type: :bulk, value: val}}) when is_bitstring(val) do
    encode_item(val)
  end

  def encode(%Connection{response: %{type: :bulk, value: val}}) when is_list(val) do
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
