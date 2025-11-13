defmodule Server.PingHandler do

  alias Server.Message

  @spec ping(Message.t()) :: Message.t()
  def ping(%Message{} = message) do
    %{message | reply: {:simple, "PONG"}}
  end
end
