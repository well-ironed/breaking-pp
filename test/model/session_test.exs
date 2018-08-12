defmodule BreakingPP.Model.SessionTest do
  use ExUnit.Case, async: true
  alias BreakingPP.Model.{Node, Session}

  test "it can be created with node, id" do
    n = Node.new(1)
    assert Session.new(n, "foo") == %Session{node: n, id: "foo"}
  end 

  test "node can be accessed" do
    n = Node.new(1)
    s = Session.new(n, "id")
    assert Session.node(s) == n
  end

  test "id can be accessed" do
    s = given_session("bar")
    assert Session.id(s) == "bar"
  end

  defp given_session(id) do
    n = Node.new(1)
    Session.new(n, id)
  end
end
