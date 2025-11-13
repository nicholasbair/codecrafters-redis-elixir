defmodule Server.EchoHandler do

  alias Server.Message

  @spec echo(Message.t()) :: Message.t()
  def echo(%Message{} = message) do
    %{message | reply: {:bulk, message.value}}
  end
end
