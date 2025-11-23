defmodule Server.Router do

  alias Server.{
    Connection,
    Request,
    Response,
    Store
  }

  @spec dispatch(Connection.t()) :: Connection.t()
  def dispatch(%Connection{} = conn) do
    spec = handlers(conn.request.command)
    result = spec.handler.(conn.request)
    %{conn | response: Response.new(spec.reply_type, result)}
  end

  @spec handlers(String.t()) :: map()
  defp handlers(cmd) do
    %{
      # Specific handler
      "PING" => %{handler: &ping/1, reply_type: :simple},
      "ECHO" => %{handler: &echo/1, reply_type: :bulk},
      "SET" => %{handler: &set/1, reply_type: :simple},

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
    }
    |> Map.fetch!(cmd)
  end

  @spec default(Request.t()) :: {:ok, any()} | {:error, String.t() | :unhandled_command}
  defp default(%Request{} = req), do: Store.transaction(req)

  @spec ping(Request.t()) :: {:ok, String.t()}
  defp ping(_req), do: {:ok, "PONG"}

  @spec echo(Request.t()) :: {:ok, String.t()}
  defp echo(%Request{} = req), do: {:ok, req.value}

  @spec set(Request.t()) :: {:ok, String.t()}
  defp set(%Request{} = req) do
    :ok = Store.transaction(req)
    {:ok, "OK"}
  end
end
