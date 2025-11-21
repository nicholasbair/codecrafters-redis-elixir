defmodule Server.Store.Commands.Blpop do

  alias Server.{
    Request,
    Store.Commands.Lpop,
  }

  @spec execute(Request.t(), map()) :: {:block, map()} | {list(), map()}
  def execute(%Request{key: keys} = req, state) do
    lpop_result =
      keys
      |> Enum.map(fn k -> {k, Lpop.execute(%{req | key: k}, state)} end)
      |> Enum.find({nil, state}, fn {_key, {val, _new_state}} -> val end)

    case lpop_result do
      {nil, state} -> {:block, state}
      {key, {val, new_state}} -> {[key, val], new_state}
    end
  end
end
