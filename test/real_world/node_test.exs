defmodule BreakingPP.RealWorld.NodeTest do
  use ExUnit.Case, async: true
  alias BreakingPP.RealWorld.Node

  test "it can be created with number and lazy host" do
    host_fun = fn -> "localhost" end
    assert Node.new(1, host_fun) == %Node{id: 1, host: host_fun, port: 4000}
  end

  test "node id can be accessed" do
    n = Node.new(1, fn -> "abc" end)
    assert Node.id(n) == 1
  end

  test "node host can be accessed" do
    n = Node.new(2, fn -> "localhost" end)
    assert Node.host(n) == "localhost"
  end

  test "node port can accessed" do
    n = Node.new(3, fn -> "foo" end)
    assert Node.port(n) == 4000
  end
end
