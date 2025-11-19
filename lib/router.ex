defmodule Server.Router do

  alias Server.{
    Connection,
    CoreHandler,
    EchoHandler,
    PingHandler
  }

  @spec dispatch(Connection.t()) :: Connection.t()
  def dispatch(%Connection{} = conn) do
    case conn.request.command do
      "PING" -> PingHandler.ping(conn)
      "ECHO" -> EchoHandler.echo(conn)
      "SET" -> CoreHandler.set(conn)
      "GET" -> CoreHandler.get(conn)
      "RPUSH" -> CoreHandler.rpush(conn)
      "LPUSH" -> CoreHandler.lpush(conn)
      "LRANGE" -> CoreHandler.lrange(conn)
      "LLEN" -> CoreHandler.llen(conn)
      "LPOP" -> CoreHandler.lpop(conn)
    end
  end
end
