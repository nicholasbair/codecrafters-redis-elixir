defmodule Server.Response do

  @type t :: %__MODULE__{
    type: :simple | :bulk,
    value: value()
  }

  @type value :: {:ok, nil | String.t() | integer() | list()} | {:error, String.t() | atom()}

  defstruct [
    :type,
    :value
  ]

  @spec new(:simple | :bulk, {:ok, value()} | {:error, String.t() | atom()}) :: t()
  def new(type, value) do
    %__MODULE__{
      type: type,
      value: value
    }
  end
end
