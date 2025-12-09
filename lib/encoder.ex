defmodule Server.Encoder do

  alias Server.Connection, as: Conn

  @crlf "\r\n"

  @spec encode(Conn.t()) :: Conn.t()
  def encode(%Conn{request: %{command: "TYPE"}, response: %{type: :simple, value: {:ok, nil}}} = conn) do
    insert_raw_response(conn, "+none#{@crlf}")
  end

  def encode(%Conn{response: %{value: {:error, msg}}} = conn) when is_bitstring(msg) do
    insert_raw_response(conn, "-ERR #{msg}#{@crlf}")
  end

  def encode(%Conn{response: %{type: :simple, value: {:ok, val}}} = conn) when is_bitstring(val) or is_atom(val) do
    insert_raw_response(conn, "+#{val}#{@crlf}")
  end

  def encode(%Conn{response: %{type: :simple, value: {:ok, val}}} = conn) when is_integer(val) do
    insert_raw_response(conn, ":#{val}#{@crlf}")
  end

  # TODO: BLPOP, XREAD BLOCK requires null array, ideally spec from router passes this
  def encode(%Conn{request: %{command: cmd}, response: %{type: :bulk, value: {:ok, nil}}} = conn) when cmd in ["BLPOP", "XREAD"] do
    insert_raw_response(conn, "*-1" <> @crlf)
  end
  def encode(%Conn{response: %{type: :bulk, value: {:ok, nil}}} = conn) do
    insert_raw_response(conn, "$-1" <> @crlf)
  end

  def encode(%Conn{response: %{type: :bulk, value: {:ok, val}}} = conn) when is_bitstring(val) do
    insert_raw_response(conn, encode_item(val))
  end

  def encode(%Conn{response: %{type: :bulk, value: {:ok, val}}} = conn) when is_list(val) do
    insert_raw_response(conn, "*#{length(val)}" <> @crlf <> encode_items(val))
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

  defp insert_raw_response(conn, raw) do
    %{conn | response: %{conn.response | raw: raw}}
  end
end
