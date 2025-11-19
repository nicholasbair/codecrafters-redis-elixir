defmodule Server.Store.Commands.Set do

  alias Server.Request.Options
  import Server.Store, only: [build_record: 2]

  @spec execute(String.t(), any(), Options.t(), map()) :: map()
  def execute(key, value, options, state) do
    Map.put(state, key, build_record(value, options))
  end
end
