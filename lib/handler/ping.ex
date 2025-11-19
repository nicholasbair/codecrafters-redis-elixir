defmodule Server.PingHandler do

  alias Server.{
    Connection,
    Response
  }

  @spec ping(Connection.t()) :: Connection.t()
  def ping(%Connection{} = conn) do
    %{conn | response: Response.new(:simple, "PONG")}
  end
end
