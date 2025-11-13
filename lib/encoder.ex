defmodule Server.Encoder do

  alias Server.Message

  @crlf "\r\n"

  @spec encode(Message.t()) :: String.t()
  def encode(%Message{reply: {:simple, val}}), do: "+#{val}#{@crlf}"
  def encode(%Message{reply: {:bulk, val}}) do
    "$#{String.length(val)}" <> @crlf <> val <> @crlf
  end
end
