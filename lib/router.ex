defmodule Server.Router do

  alias Server.{
    EchoHandler,
    PingHandler,
    Message
  }

  @spec route(Message.t()) :: Message.t()
  def route(%Message{command: "PING"} = message), do: PingHandler.ping(message)
  def route(%Message{command: "ECHO"} = message), do: EchoHandler.echo(message)
end
