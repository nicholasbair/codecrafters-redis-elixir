defmodule Server.Message do

  @type t :: %__MODULE__{
    command: String.t() | nil,
    raw: String.t(),
    reply: reply() | nil,
    value: String.t() | tuple() | nil,
  }

  @type reply :: {type :: :simple | :bulk, value :: String.t()}

  defstruct [
    :command,
    :raw,
    :reply,
    :value
  ]

  @spec new(String.t()) :: t()
  def new(raw) do
    %__MODULE__{
      raw: raw
    }
  end
end
