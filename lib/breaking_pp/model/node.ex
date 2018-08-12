defmodule BreakingPP.Model.Node do
  defstruct [:id]

  def new(id), do: %__MODULE__{id: id}
  def id(%__MODULE__{id: id}), do: id

end 

