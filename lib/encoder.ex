defmodule Server.Encoder do

  alias Server.Message

  @crlf "\r\n"

  @spec encode(Message.t()) :: String.t()
  def encode(%Message{reply: {:simple, val}}) when is_bitstring(val), do: "+#{val}#{@crlf}"
  def encode(%Message{reply: {:simple, val}}) when is_integer(val), do: ":#{val}#{@crlf}"

  def encode(%Message{reply: {:bulk, nil}}), do: "$-1" <> @crlf

  def encode(%Message{reply: {:bulk, val}}) do
    "$#{String.length(val)}" <> @crlf <> val <> @crlf
  end
end
