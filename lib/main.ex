defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application
  require Logger

  alias Server.{
    Decoder,
    Encoder,
    Message,
    Router
  }

  def start(_type, _args) do
    children = [
      {Server.Store, name: Server.Store},
      {Task.Supervisor, name: Server.MessageSupervisor},
      Supervisor.child_spec({Task, fn -> Server.listen() end}, restart: :permanent)
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc """
  Listen for incoming connections
  """
  def listen() do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # ensures that we don't run into 'Address already in use' errors
    {:ok, socket} = :gen_tcp.listen(6379, [:binary, packet: :raw, active: false, reuseaddr: true])
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Server.MessageSupervisor, fn -> handle_message_loop(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  defp handle_message_loop(client) do
    case :gen_tcp.recv(client, 0) do
      {:ok, message} -> handle_message(message, client)
      {:error, reason} -> Logger.error("TCP receive error: #{inspect(reason)}")
    end

    handle_message_loop(client)
  end

  defp handle_message(message, client) do
    message
    |> Message.new()
    |> Decoder.decode()
    |> Router.dispatch()
    |> Encoder.encode()
    |> then(&:gen_tcp.send(client, &1))
  end
end

defmodule CLI do
  def main(_args) do
    # Start the Server application
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_redis)

    # Run forever
    Process.sleep(:infinity)
  end
end
