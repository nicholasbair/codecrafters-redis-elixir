defmodule Server.CoreHandler do

  alias Server.{
    Connection,
    Response,
    Store
  }

  # TODO: protocol specifies the return type, need to implement that instead of hard coding here

  @spec lpop(Connection.t()) :: Connection.t()
  def lpop(%Connection{} = conn) do
    {:ok, val} = Store.transaction(conn.request)
    %{conn | response: Response.new(:bulk, val)}
  end

  @spec llen(Connection.t()) :: Connection.t()
  def llen(%Connection{} = conn) do
    {:ok, val} = Store.transaction(conn.request)
    %{conn | response: Response.new(:simple, val)}
  end

  @spec lrange(Connection.t()) :: Connection.t()
  def lrange(%Connection{} = conn) do
    {:ok, val} = Store.transaction(conn.request)
    %{conn | response: Response.new(:bulk, val)}
  end

  @spec rpush(Connection.t()) :: Connection.t()
  def rpush(%Connection{} = conn) do
    {:ok, val} = Store.transaction(conn.request)
    %{conn | response: Response.new(:simple, val)}
  end

  @spec lpush(Connection.t()) :: Connection.t()
  def lpush(%Connection{} = conn) do
    {:ok, val} = Store.transaction(conn.request)
    %{conn | response: Response.new(:simple, val)}
  end

  @spec set(Connection.t()) :: Connection.t()
  def set(%Connection{} = conn) do
    Store.transaction(conn.request)
    %{conn | response: Response.new(:simple, "OK")}
  end

  @spec get(Connection.t()) :: Connection.t()
  def get(%Connection{} = conn) do
    {:ok, val} = Store.transaction(conn.request)
    %{conn | response: Response.new(:bulk, val)}
  end
end
