defmodule Server.CoreHandler do

  alias Server.{
    Message,
    Store
  }

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
