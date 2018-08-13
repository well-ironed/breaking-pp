defmodule BreakingPP.Test.Model.NodeTest do
  use ExUnit.Case, async: true
  alias BreakingPP.Model.Node

  test "it can be created with id" do
    assert %Node{id: 3} = Node.new(3)
  end

  test "id can be accessed" do
    n = Node.new(42)
    assert Node.id(n) == 42
  end

end
