defmodule BreakingPP.RealWorld.NodeTest do
  use ExUnit.Case, async: true
  alias BreakingPP.RealWorld.Node

  test "it can be created with number and host" do
    assert Node.new(1, "localhost") ==
      %Node{id: 1, host: "localhost", port: 4000}
  end

  test "node id can be accessed" do
    n = Node.new(1, "abc")
    assert Node.id(n) == 1
  end

  test "node host can be accessed" do
    n = Node.new(2, "localhost")
    assert Node.host(n) == "localhost"
  end

  test "node port can accessed" do
    n = Node.new(3, "foo")
    assert Node.port(n) == 4000
  end
end
