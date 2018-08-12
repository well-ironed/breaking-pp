defmodule BreakingPP.Model.Session do
  alias BreakingPP.Model.Node
  defstruct [:node, :id]

  @type t :: %__MODULE__{node: Node.t, id: String.t}

  def new(node, id) do
    %__MODULE__{node: node, id: id}
  end

  def node(%__MODULE__{node: node}), do: node

  def id(%__MODULE__{id: id}), do: id
end
