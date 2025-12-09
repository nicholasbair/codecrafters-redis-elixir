defmodule Server.Connection do

  alias Server.{
    Request,
    Response
  }

  @type t :: %__MODULE__{
    request: Request.t(),
    response: Response.t() | nil,
    multi?: boolean(),
    queue: :queue.queue() | nil
  }

  defstruct [
    :queue,
    :request,
    :response,
    multi?: false
  ]
end
