defmodule BreakingPP.RealWorld.Session do
  defstruct [:node, :id, :socket]
  alias BreakingPP.RealWorld.Node

  @type id :: String.t
  @type t :: %__MODULE__{
    node: RealWorld.Node.t,
    id: id,
    socket: Socket.Web.t}

  def new(node, id) do
    s = Socket.Web.connect!(
      Node.host(node), Node.port(node), path: "/sessions/#{id}")
    Socket.active(s.socket)
    %__MODULE__{node: node, id: id, socket: s}
  end

  def close(%__MODULE__{socket: s}) do
    Socket.Web.close(s)
  end

  def node(%__MODULE__{node: n}), do: n

end
