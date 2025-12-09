defmodule Server.Response do

  @type t :: %__MODULE__{
    raw: String.t(),
    type: response_type(),
    value: value()
  }

  @type value :: {:ok, nil | String.t() | integer() | list()} | {:error, String.t() | atom()}
  @type response_type :: :simple | :bulk

  defstruct [
    :type,
    :value,
    raw: "",
  ]

  @spec new(value(), response_type()) :: t()
  def new(value, type) do
    %__MODULE__{
      type: type,
      value: value
    }
  end
end
