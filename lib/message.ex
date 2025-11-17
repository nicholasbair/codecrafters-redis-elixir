defmodule Server.Message do

  alias Server.Message.Options

  @type t :: %__MODULE__{
    command: String.t() | nil,
    raw: String.t(),
    reply: reply() | nil,
    key: String.t() | nil,
    value: String.t() | nil,
    options: Options.t() | nil
  }

  @type reply :: {type :: :simple | :bulk, value :: String.t()}

  defstruct [
    :command,
    :raw,
    :reply,
    :key,
    :value,
    :options
  ]

  defmodule Options do
    defstruct [
      :ttl_ms,
      :expire_at_ms,
      :precondition,
      return_previous?: false,
      keep_ttl?: false,
      clear_ttl?: false
    ]

    @type t :: %__MODULE__{
      ttl_ms: integer() | nil,
      expire_at_ms: integer() | nil,
      precondition: :only_if_present | :only_if_absent | nil,
      return_previous?: boolean(),
      keep_ttl?: boolean(),
      clear_ttl?: boolean()
    }
  end

  @spec new(String.t()) :: t()
  def new(raw) do
    %__MODULE__{
      raw: raw
    }
  end
end
