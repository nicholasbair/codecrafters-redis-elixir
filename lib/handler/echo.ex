defmodule Server.EchoHandler do

  alias Server.{
    Connection,
    Response
  }

  @spec echo(Connection.t()) :: Connection.t()
  def echo(%Connection{} = conn) do
    %{conn | response: Response.new(:bulk, conn.request.value)}
  end
end
