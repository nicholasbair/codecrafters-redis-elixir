defmodule Server.Store do

  use GenServer
  alias Server.Message

  # Client

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def transaction(%Message{} = message) do
    GenServer.call(__MODULE__, message)
  end

  # Server

  def init(_) do
    {:ok, %{}}
  end

  def handle_call(%Message{command: "SET", value: {k, v}}, _from, state) do
    new_state = Map.put(state, k, v)
    {:reply, :ok, new_state}
  end

  def handle_call(%Message{command: "GET", value: k}, _from, state) do
    {:reply, {:ok, Map.get(state, k)}, state}
  end

  def handle_call(%Message{}, _from, state) do
    {:reply, {:error, :unhandled_command}, state}
  end
end
