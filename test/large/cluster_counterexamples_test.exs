defmodule BreakingPP.CounterExamplesTest do
  use ExUnit.Case
  import BreakingPP.Eventually
  alias BreakingPP.RealWorld.Cluster

  @moduletag timeout: 300_000

  test "counterexample 1" do
    [n1, n2, n3] = Cluster.start(3)

    Cluster.connect(n1, ["101"])
    Cluster.connect(n2, ids(201..252))
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n1, n2, n3]) ==
        List.duplicate(["101"] ++ ids(201..252), 3)
    end)

    Cluster.stop_node(n3)
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n1, n2]) ==
        List.duplicate(["101"] ++ ids(201..252), 2)
    end)

    Cluster.disconnect(ids(201..251))
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n1, n2]) == [["101", "252"], ["101", "252"]]
    end)

    Cluster.stop_node(n1)
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n2]) == [["252"]]
    end)

    Cluster.start_node(n3)
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n2, n3]) == [["252"], ["252"]]
    end, 60, 1_000)
  end

  test "counterexample 2" do
    [n1, n2, n3] = Cluster.start(3)

    Cluster.stop_node(n1)
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n2, n3]) == [[], []]
    end)

    Cluster.connect(n2, ids(201..270))
    Cluster.connect(n3, ids(301..383))
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n2, n3]) == 
        List.duplicate(ids(201..270) ++ ids(301..383), 2)
    end)

    Cluster.stop_node(n3)
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n2]) == [ids(201..270)]
    end)

    Cluster.start_node(n1)
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n1, n2]) == List.duplicate(ids(201..270), 2)
    end, 60, 1_000)
  end

  defp ids(range), do: Enum.map(range, &Integer.to_string/1)
end
