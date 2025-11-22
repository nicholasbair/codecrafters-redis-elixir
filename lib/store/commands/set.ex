defmodule Server.Store.Commands.Set do

  alias Server.{
    Request,
    Store.Record,
    Store.State
  }

  @spec execute(Request.t(), State.record_state()) :: State.record_state()
  def execute(%Request{key: key, value: value} = req, state) do
    Map.put(state, key, build_record(value, req))
  end

  @spec build_record(any(), Request.t()) :: Record.t()
  defp build_record(value, %Request{options: nil}), do: %Record{value: value, type: :string}

  defp build_record(value, %Request{start_time: start, options: %{ttl_ms: ttl}}) do
    %Record{value: value, expire_at: start + ttl, type: :string}
  end

  defp build_record(value, %Request{options: %{expire_at_ms: time}}) do
    %Record{value: value, expire_at: time, type: :string}
  end
end
