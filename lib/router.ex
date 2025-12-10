defmodule Server.Router do

  alias Server.Connection, as: Conn
  alias Server.{
    Request,
    Response,
    Store
  }

  @spec dispatch(Conn.t()) :: Conn.t()
  def dispatch(%Conn{multi?: true, request: %{command: cmd}} = conn) when cmd not in ["EXEC", "DISCARD"] do
    %{
      conn |
      queue: enqueue(conn.queue, conn.request),
      response: Response.new({:ok, "QUEUED"}, :simple)
    }
  end

  def dispatch(%Conn{} = conn) do
    spec = handlers(conn.request.command)
    {updated_conn, result} = spec.handler.(conn)

    %{updated_conn | response: Response.new(result, spec.reply_type)}
  end

  @spec handlers(String.t()) :: map()
  defp handlers(cmd) do
    %{
      # Specific handler
      "PING" => %{handler: &ping/1, reply_type: :simple},
      "ECHO" => %{handler: &echo/1, reply_type: :bulk},
      "SET" => %{handler: &set/1, reply_type: :simple},
      "MULTI" => %{handler: &multi/1, reply_type: :simple},
      "EXEC" => %{handler: &exec/1, reply_type: :bulk},
      "DISCARD" => %{handler: &discard/1, reply_type: :simple},
      "INFO" => %{handler: &info/1, reply_type: :bulk},

      # Default handler
      "GET" => %{handler: &default/1, reply_type: :bulk},
      "RPUSH" => %{handler: &default/1, reply_type: :simple},
      "LPUSH" => %{handler: &default/1, reply_type: :simple},
      "LRANGE" => %{handler: &default/1, reply_type: :bulk},
      "LLEN" => %{handler: &default/1, reply_type: :simple},
      "LPOP" => %{handler: &default/1, reply_type: :bulk},
      "BLPOP" => %{handler: &default/1, reply_type: :bulk},
      "TYPE" => %{handler: &default/1, reply_type: :simple},
      "XADD" => %{handler: &default/1, reply_type: :bulk},
      "XRANGE" => %{handler: &default/1, reply_type: :bulk},
      "XREAD" => %{handler: &default/1, reply_type: :bulk},
      "INCR" => %{handler: &default/1, reply_type: :simple},
    }
    |> Map.get(cmd, %{handler: &unhandled_command/1, reply_type: :simple})
  end

  @spec unhandled_command(Conn.t()) :: {Conn.t(), {:error, String.t()}}
  defp unhandled_command(conn), do: {conn, {:error, "unhandled command: #{conn.request.command}"}}

  @spec default(Conn.t()) :: {Conn.t(), {:ok, any()} | {:error, String.t() | :unhandled_command}}
  defp default(%Conn{} = conn), do: {conn, Store.transaction(conn.request)}

  @spec ping(Conn.t()) :: {Conn.t(), {:ok, String.t()}}
  defp ping(conn), do: {conn, {:ok, "PONG"}}

  @spec echo(Conn.t()) :: {Conn.t(), {:ok, String.t()}}
  defp echo(%Conn{} = conn), do: {conn, {:ok, conn.request.value}}

  @spec set(Conn.t()) :: {Conn.t(), {:ok, String.t()}}
  defp set(%Conn{} = conn) do
    :ok = Store.transaction(conn.request)
    {conn, {:ok, "OK"}}
  end

  @spec multi(Conn.t()) :: {Conn.t(), {:ok, String.t()}}
  defp multi(%Conn{} = conn) do
    updated_conn = %{conn | multi?: true}
    {updated_conn, {:ok, "OK"}}
  end

  @spec exec(Conn.t()) :: {Conn.t(), {:ok, list()}}
  defp exec(%Conn{multi?: false} = conn) do
    {conn, {:error, "EXEC without MULTI"}}
  end

  defp exec(%Conn{} = conn) do
    connections =
      conn.queue
      |> queue_to_list()
      |> Enum.map(fn req ->
        spec = handlers(req.command)
        {_updated_conn, result} = spec.handler.(%Conn{request: req})

        %Conn{
          request: req,
          response: Response.new(result, spec.reply_type)
        }
      end)

    updated_conn = %{conn | multi?: false, queue: nil}
    {updated_conn, {:ok, connections}}
  end

  @spec discard(Conn.t()) :: {Conn.t(), {:ok, String.t()}}
  defp discard(%Conn{multi?: false} = conn) do
    {conn, {:error, "DISCARD without MULTI"}}
  end

  defp discard(%Conn{} = conn) do
    updated_conn = %{conn | multi?: false, queue: nil}
    {updated_conn, {:ok, "OK"}}
  end

  @spec info(Conn.t()) :: {Conn.t(), {:ok, String.t()} | {:error, String.t()}}
  def info(%Conn{request: %{key: "replication"}} = conn) do
    res = [
      "role:#{Application.get_env(Server, :role, "master")}",
      "master_replid:#{Application.get_env(Server, :master_replid)}",
      "master_repl_offset:#{Application.get_env(Server, :master_repl_offset)}"
    ]

    {conn, {:ok, Enum.join(res, "\n")}}
  end

  def info(%Conn{} = conn) do
    {conn, {:error, "INFO option #{conn.request.key} not supported"}}
  end

  @spec enqueue(:queue.queue() | nil, Request.t()) :: :queue.queue()
  defp enqueue(nil, req) do
    q = :queue.new()
    :queue.in(req, q)
  end
  defp enqueue(queue, req), do: :queue.in(req, queue)

  @spec queue_to_list(:queue.queue() | nil) :: list()
  defp queue_to_list(nil), do: []
  defp queue_to_list(q), do: :queue.to_list(q)
end
