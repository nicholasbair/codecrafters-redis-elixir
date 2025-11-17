defmodule Server.Decoder do

  alias Server.{
    Message,
    Message.Options
  }

  @crlf "\r\n"

  @spec decode(Message.t()) :: Message.t()
  def decode(%Message{raw: raw} = message) do
    [elements | rest] = String.split(raw, @crlf)
    num_elements = parse_num_elements(elements)

    rest
    |> Enum.chunk_every(2)
    |> Enum.take(num_elements)
    |> Enum.map(&parse_chunk/1)
    |> into_message(message)
  end

  @spec parse_num_elements(String.t()) :: non_neg_integer()
  defp parse_num_elements(elements) do
    elements
    |> String.split_at(1)
    |> then(fn {_, n} -> String.to_integer(n) end)
  end

  @spec parse_chunk([String.t()]) :: String.t()
  defp parse_chunk([_type, val]), do: val

  @spec into_message([String.t()], Message.t()) :: Message.t()
  defp into_message([hd | tl], %Message{command: nil} = message) do
    into_message(tl, %{message | command: hd})
  end

  defp into_message([hd | tl], %Message{command: cmd, key: nil} = message) when cmd in ["GET", "SET"] do
    into_message(tl, %{message | key: hd})
  end

  defp into_message([hd | tl], %Message{command: cmd, value: nil} = message) when cmd in ["ECHO"] do
    into_message(tl, %{message | value: hd})
  end

  defp into_message([hd | tl], %Message{command: "SET", value: nil} = message) do
    into_message(tl, %{message | value: hd})
  end

  defp into_message(parts, %Message{options: nil} = message) when length(parts) > 0 do
    %{message | options: parse_options(parts, %Options{})}
  end

  defp into_message([], message), do: message

  @spec parse_options([String.t()], Options.t()) :: Options.t()
  defp parse_options(["EX", ttl | rest], options) do
    parse_options(rest, %{options | ttl_ms: String.to_integer(ttl) * 1000})
  end

  defp parse_options(["PX", ttl | rest], options) do
    parse_options(rest, %{options | ttl_ms: String.to_integer(ttl)})
  end

  defp parse_options(["EXAT", time | rest], options) do
    parse_options(rest, %{options | expire_at_ms: String.to_integer(time) * 1000})
  end

  defp parse_options(["PXAT", time | rest], options) do
    parse_options(rest, %{options | expire_at_ms: String.to_integer(time)})
  end

  defp parse_options(["NX" | rest ], options) do
    parse_options(rest, %{options | precondition: :only_if_absent})
  end

  defp parse_options(["XX" | rest], options) do
    parse_options(rest, %{options | precondition: :only_if_present})
  end

  defp parse_options(["GET" | rest], options) do
    parse_options(rest, %{options | return_previous?: true})
  end

  defp parse_options(["KEEPTTL" | rest], options) do
    parse_options(rest, %{options | keep_ttl?: true})
  end

  defp parse_options(["PERSIST" | rest], options) do
    parse_options(rest, %{options | clear_ttl?: true})
  end

  defp parse_options([], options), do: options
end
