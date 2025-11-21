defmodule Server.Util do

  @spec now() :: non_neg_integer()
  def now() do
    DateTime.utc_now()
    |> DateTime.to_unix(:millisecond)
  end

end
