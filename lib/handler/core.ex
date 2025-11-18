defmodule Server.CoreHandler do

  alias Server.{
    Message,
    Store
  }

  # TODO: protocol specifies the return type, need to implement that instead of hard coding here

  @spec llen(Message.t()) :: Message.t()
  def llen(%Message{} = message) do
    {:ok, val} = Store.transaction(message)
    %{message | reply: {:simple, val}}
  end

  @spec lrange(Message.t()) :: Message.t()
  def lrange(%Message{} = message) do
    {:ok, val} = Store.transaction(message)
    %{message | reply: {:bulk, val}}
  end

  @spec rpush(Message.t()) :: Message.t()
  def rpush(%Message{} = message) do
    {:ok, val} = Store.transaction(message)
    %{message | reply: {:simple, val}}
  end

  @spec lpush(Message.t()) :: Message.t()
  def lpush(%Message{} = message) do
    {:ok, val} = Store.transaction(message)
    %{message | reply: {:simple, val}}
  end

  @spec set(Message.t()) :: Message.t()
  def set(%Message{} = message) do
    Store.transaction(message)
    %{message | reply: {:simple, "OK"}}
  end

  @spec get(Message.t()) :: Message.t()
  def get(%Message{} = message) do
    {:ok, val} = Store.transaction(message)
    %{message | reply: {:bulk, val}}
  end
end
