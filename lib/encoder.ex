defmodule Server.Encoder do

  alias Server.Connection

  @crlf "\r\n"

  @spec encode(Connection.t()) :: String.t()
  def encode(%Connection{request: %{command: "TYPE"}, response: %{type: :simple, value: {:ok, nil}}}) do
    "+none#{@crlf}"
  end

  def encode(%Connection{response: %{value: {:error, msg}}}) when is_bitstring(msg) do
    "-ERR #{msg}#{@crlf}"
  end

  def encode(%Connection{response: %{type: :simple, value: {:ok, val}}}) when is_bitstring(val) or is_atom(val) do
    "+#{val}#{@crlf}"
  end

  def encode(%Connection{response: %{type: :simple, value: {:ok, val}}}) when is_integer(val) do
    ":#{val}#{@crlf}"
  end

  # TODO: BLPOP, XREAD BLOCK requires null array, ideally spec from router passes this
  def encode(%Connection{request: %{command: cmd}, response: %{type: :bulk, value: {:ok, nil}}}) when cmd in ["BLPOP", "XREAD"] do
    "*-1" <> @crlf
  end
  def encode(%Connection{response: %{type: :bulk, value: {:ok, nil}}}), do: "$-1" <> @crlf

  def encode(%Connection{response: %{type: :bulk, value: {:ok, val}}}) when is_bitstring(val) do
    encode_item(val)
  end

  def encode(%Connection{response: %{type: :bulk, value: {:ok, val}}}) when is_list(val) do
    "*#{length(val)}" <> @crlf <> encode_items(val)
  end

  @spec encode_items([String.t()]) :: String.t()
  defp encode_items(items) when is_list(items) do
    Enum.reduce(items, "", fn i, acc -> acc <> encode_item(i) end)
  end

  defp encode_item(item) when is_bitstring(item) do
    "$#{String.length(item)}" <> @crlf <> item <> @crlf
  end

  # Ensure list of list is properly encoded
  defp encode_item(item) when is_list(item) do
    "*#{length(item)}" <> @crlf <> encode_items(item)
  end
end
