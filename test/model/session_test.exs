defmodule BreakingPP.Model.SessionTest do
  use ExUnit.Case, async: true
  alias BreakingPP.Model.{Node, Session}

  test "it can be created with node, id and socket" do
    n = Node.new(1, fn -> "localhost" end)
    s = %Socket.Web{}
    assert Session.new(n, "foo", s) == %Session{node: n, id: "foo", socket: s}
  end 

  test "socket can be accessed" do
    s = given_session("1")
    assert %Socket.Web{} = Session.socket(s)
  end

  test "node can be accessed" do
    n = Node.new(1, fn -> "foo" end)
    s = Session.new(n, "id", %Socket.Web{})
    assert Session.node(s) == n
  end

  test "id can be accessed" do
    s = given_session("bar")
    assert Session.id(s) == "bar"
  end

  defp given_session(id) do
    n = Node.new(1, fn -> "foo" end)
    Session.new(n, id, %Socket.Web{})
  end
end
