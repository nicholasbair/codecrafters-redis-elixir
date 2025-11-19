defmodule Server.Connection do

  alias Server.{
    Request,
    Response
  }

  @type t :: %__MODULE__{
    request: Request.t(),
    response: Response.t() | nil
  }

  defstruct [
    :request,
    :response
  ]

  @spec with_new_request(String.t()) :: t()
  def with_new_request(raw) do
    %__MODULE__{
      request: Request.new(raw)
    }
  end
end
