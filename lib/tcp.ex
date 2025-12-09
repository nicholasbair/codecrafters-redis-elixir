defmodule Server.Tcp do

  alias Server.Connection, as: Conn

  @type socket :: :inet.socket()

  @spec send(Conn.t(), socket()) :: Conn.t()
  def send(%Conn{response: %{raw: raw}} = conn, client) do
    :gen_tcp.send(client, raw)
    conn
  end
end
