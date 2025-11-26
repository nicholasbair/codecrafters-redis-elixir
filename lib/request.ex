defmodule Server.Request do

  alias Server.{
    Request.Options,
    Util
  }

  @type t :: %__MODULE__{
    command: String.t() | nil,
    key: String.t() | list() | nil,
    value: String.t() | list() | map() | tuple() | nil,
    options: Options.t() | nil,
    raw: String.t() | nil,
    start_time: non_neg_integer() | nil
  }

  defstruct [
    :command,
    :key,
    :value,
    :options,
    :raw,
    :start_time
  ]

  defmodule Options do
    @type t :: %__MODULE__{
      ttl_ms: integer() | nil,
      expire_at_ms: integer() | nil,
      precondition: :only_if_present | :only_if_absent | nil,
      timeout: non_neg_integer() | :infinity | nil,
      return_previous?: boolean(),
      keep_ttl?: boolean(),
      clear_ttl?: boolean(),
      block?: boolean()
    }

    defstruct [
      :ttl_ms,
      :expire_at_ms,
      :precondition,
      :timeout,
      return_previous?: false,
      keep_ttl?: false,
      clear_ttl?: false,
      block?: false
    ]
  end

  @spec new(String.t()) :: t()
  def new(raw) do
    %__MODULE__{
      raw: raw,
      start_time: Util.now()
    }
  end
end
