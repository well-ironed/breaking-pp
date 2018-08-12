defmodule BreakingPP.Test.Session do
  alias BreakingPP.Model.{Node, Session}

  def connect(node, id) do
    s = Socket.Web.connect!(
      Node.host(node), Node.port(node), path: "/sessions/#{id}")
    Socket.active(s.socket)
    Session.new(node, id, s)
  end

  def disconnect(session) do
    Socket.Web.close(Session.socket(session))
  end

end
