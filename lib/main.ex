defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application
  require Logger

  alias Server.Connection, as: Conn
  alias Server.{
    Encoder,
    Parser,
    Request,
    Router,
    Tcp
  }

  @default_port 6379

  def start(_type, _args) do
    opts = parse_cli_args()
    set_app_info(opts)

    children = [
      {Server.Store, name: Server.Store},
      {Task.Supervisor, name: Server.MessageSupervisor},
      Supervisor.child_spec({Task, fn -> Server.listen(opts) end}, restart: :permanent)
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc """
  Listen for incoming connections
  """
  def listen(opts \\ []) do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    port = Keyword.get(opts, :port, @default_port)

    # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # ensures that we don't run into 'Address already in use' errors
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Server.MessageSupervisor, fn -> handle_message_loop(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)

    loop_acceptor(socket)
  end

  defp handle_message_loop(client, conn \\ nil) do
    # Preserve state for multi
    base_conn = conn || %Conn{}

    case :gen_tcp.recv(client, 0) do
      {:ok, message} ->
        new_conn =
          base_conn
          |> put_new_request(message)
          |> Parser.parse()
          |> Router.dispatch()
          |> Encoder.encode()
          |> Tcp.send(client)

        handle_message_loop(client, new_conn)

      {:error, reason} ->
        Logger.error("TCP receive error: #{inspect(reason)}")
        handle_message_loop(client, nil)
    end
  end

  @spec put_new_request(Conn.t() | nil, String.t()) :: Conn.t()
  defp put_new_request(nil, message) do
    %Conn{request: Request.new(message)}
  end

  defp put_new_request(conn, message) do
    %{conn | request: Request.new(message)}
  end

  @spec parse_cli_args() :: Keyword.t()
  defp parse_cli_args() do
    System.argv()
    |> Enum.chunk_every(2)
    |> Enum.reduce(Keyword.new(), fn [k, v], acc ->
      case k do
        "--port" -> Keyword.put(acc, :port, String.to_integer(v))
        "--replicaof" -> Keyword.put(acc, :role, "slave")
        _ -> acc
      end
    end)
  end

  @spec set_app_info(Keyword.t()) :: [:ok]
  defp set_app_info(opts) do
    for {k, v} <- opts, do: Application.put_env(__MODULE__, k, v)

    # Hardcoding for now
    Application.put_env(__MODULE__, :master_replid, "8371b4fb1155b71f4a04d3e1bc3e18c4a990aeeb")
    Application.put_env(__MODULE__, :master_repl_offset, 0)
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
