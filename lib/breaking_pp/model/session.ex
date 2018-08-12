defmodule BreakingPP.Model.Session do
  defstruct [:node, :id, :socket]

  def new(node, id, %Socket.Web{}=socket) do
    %__MODULE__{node: node, id: id, socket: socket}
  end

  def socket(%__MODULE__{socket: socket}), do: socket

  def node(%__MODULE__{node: node}), do: node

  def id(%__MODULE__{id: id}), do: id
end
