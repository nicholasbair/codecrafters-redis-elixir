defmodule Server.Parser do

  alias Server.{
    Connection,
    Request,
    Request.Options
  }

  @crlf "\r\n"

  @spec parse(Connection.t()) :: Connection.t()
  def parse(%Connection{request: req} = conn) do
    [elements | rest] = String.split(req.raw, @crlf)
    num_elements = parse_num_elements(elements)

    updated_req =
      rest
      |> Enum.chunk_every(2)
      |> Enum.take(num_elements)
      |> Enum.map(&parse_chunk/1)
      |> into_request(req)

    %{conn | request: updated_req}
  end

  @spec parse_num_elements(String.t()) :: non_neg_integer()
  defp parse_num_elements(elements) do
    elements
    |> String.split_at(1)
    |> then(fn {_, n} -> String.to_integer(n) end)
  end

  @spec parse_chunk([String.t()]) :: String.t()
  defp parse_chunk([_type, val]), do: val

  defp into_request([cmd | tl], %Request{command: nil} = req) do
    transformers(cmd).(tl, %{req | command: cmd})
  end

  @spec transformers(String.t()) :: fun()
  defp transformers(cmd) do
    %{
      "ECHO" => &transform_echo/2,
      "GET" => &transform_get/2,
      "SET" => &transform_set/2,
      "RPUSH" => &transform_rpush/2,
      "LPUSH" => &transform_lpush/2,
      "LRANGE" => &transform_lrange/2,
      "LLEN" => &transform_llen/2,
      "LPOP" => &transform_lpop/2,
      "BLPOP" => &transform_blpop/2,
      "TYPE" => &transform_type/2,
      "XADD" => &transform_xadd/2,
      "XRANGE" => &transform_xrange/2,
      "XREAD" => &transform_xread/2,
    }
    |> Map.get(cmd, &transform_default/2)
  end

  @spec transform_default(list(), Request.t()) :: Request.t()
  defp transform_default(_, req), do: req

  @spec transform_echo(list(), Request.t()) :: Request.t()
  defp transform_echo([hd | _], req), do: %{req | value: hd}

  @spec transform_get(list(), Request.t()) :: Request.t()
  defp transform_get([key | _], req), do: %{req | key: key}

  @spec transform_type(list(), Request.t()) :: Request.t()
  defp transform_type([key | _], req), do: %{req | key: key}

  @spec transform_set(list(), Request.t()) :: Request.t()
  defp transform_set([key | tl], %{key: nil} = req), do: transform_set(tl, %{req | key: key})
  defp transform_set([value | opt], %{value: nil} = req), do: transform_set(opt, %{req | value: value})
  defp transform_set([], req), do: req
  defp transform_set(opt, req), do: %{req | options: parse_options(opt)}

  @spec transform_rpush(list(), Request.t()) :: Request.t()
  defp transform_rpush([key | tl], %{key: nil} = req), do: transform_rpush(tl, %{req | key: key})
  defp transform_rpush(value, req), do: %{req | value: value}

  @spec transform_lpush(list(), Request.t()) :: Request.t()
  defp transform_lpush([key | tl], %{key: nil} = req), do: transform_lpush(tl, %{req | key: key})
  defp transform_lpush(value, req), do: %{req | value: Enum.reverse(value)}

  @spec transform_lrange(list(), Request.t()) :: Request.t()
  defp transform_lrange([key | tl], %{key: nil} = req), do: transform_lrange(tl, %{req | key: key})
  defp transform_lrange(rest, req), do: %{req | value: Enum.map(rest, &String.to_integer/1)}

  @spec transform_llen(list(), Request.t()) :: Request.t()
  defp transform_llen([key | _], req), do: %{req | key: key}

  @spec transform_lpop(list(), Request.t()) :: Request.t()
  defp transform_lpop([key | tl], %{key: nil} = req), do: transform_lpop(tl, %{req | key: key})
  defp transform_lpop([value], req), do: %{req | value: String.to_integer(value)}
  defp transform_lpop([], req), do: req

  @spec transform_blpop(list(), Request.t()) :: Request.t()
  defp transform_blpop(parts, %{key: nil} = req) do
    {keys, timeout} = Enum.split(parts, -1)
    %{req | key: keys, options: %Options{timeout: parse_timeout(timeout)}}
  end

  @spec transform_xadd(list(), Request.t()) :: Request.t()
  defp transform_xadd([key | tl], %{key: nil} = req), do: transform_xadd(tl, %{req | key: key})
  defp transform_xadd([entry_id | tl], %{value: nil} = req) do
    transform_xadd(tl, %{req | value: %{entry_id: entry_id}})
  end

  defp transform_xadd([key, value | tl], req) do
    transform_xadd(tl, %{req | value: Map.put(req.value, key, value)})
  end

  defp transform_xadd([], req), do: req

  @spec transform_xrange(list(), Request.t()) :: Request.t()
  defp transform_xrange([key | tl], %{key: nil} = req), do: transform_xrange(tl, %{req | key: key})
  defp transform_xrange([s, e | _tl], %{value: nil} = req), do: %{req | value: {s, e}}

  @spec transform_xread(list(), Request.t()) :: Request.t()
  defp transform_xread([hd | tl], %{key: nil} = req) when hd in ["STREAMS", "streams"], do: transform_xread(tl, req)
  defp transform_xread(parts, %{key: nil} = req) do
    split_index = ceil(length(parts) / 2)
    {keys, values} = Enum.split(parts, split_index)
    %{req | key: keys, value: values}
  end

  @spec parse_timeout(list()) :: non_neg_integer() | :infinity
  defp parse_timeout([timeout]) do
    case to_number(timeout) do
      0 -> :infinity
      val -> trunc(val * 1000)
    end
  end

  @spec to_number(String.t()) :: integer() | float()
  defp to_number(timeout) do
    case String.match?(timeout, ~r/\./) do
      true -> String.to_float(timeout)
      false -> String.to_integer(timeout)
    end
  end

  @spec parse_options([String.t()], Options.t()) :: Options.t()
  defp parse_options(parts, acc \\ %Options{})
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
