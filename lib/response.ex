defmodule Server.Response do

  @type t :: %__MODULE__{
    type: :simple | :bulk,
    value: nil | String.t() | integer() | list()
  }

  defstruct [
    :type,
    :value
  ]

  @spec new(:simple | :bulk, String.t() | integer() | list()) :: t()
  def new(type, value) do
    %__MODULE__{
      type: type,
      value: value
    }
  end
end
