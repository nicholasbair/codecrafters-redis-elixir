defmodule Server.Router do

  alias Server.{
    CoreHandler,
    EchoHandler,
    PingHandler,
    Message
  }

  @spec dispatch(Message.t()) :: Message.t()
  def dispatch(%Message{} = message) do
    case message.command do
      "PING" -> PingHandler.ping(message)
      "ECHO" -> EchoHandler.echo(message)
      "SET" -> CoreHandler.set(message)
      "GET" -> CoreHandler.get(message)
    end
  end
end
