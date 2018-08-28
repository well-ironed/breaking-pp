defmodule BreakingPP.CounterExamplesTest do
  use ExUnit.Case
  import BreakingPP.Eventually
  alias BreakingPP.RealWorld.Cluster

  @moduletag timeout: 250_000_000

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

  test "counterexample 3" do
    [n1, n2, n3] = Cluster.start(3)

    Cluster.split(n1, n3)
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n1, n2, n3]) == [[], [], []]
    end)

    Cluster.connect(n3, ["301", "302", "303"])
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n1, n2, n3]) ==
        [[], ["301", "302", "303"], ["301", "302", "303"]]
    end)

    Cluster.disconnect(["301"])
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n1, n2, n3]) ==
        [[], ["302", "303"], ["302", "303"]]
    end)

    Cluster.disconnect(["302"])
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n1, n2, n3]) == [[], ["303"], ["303"]]
    end)

    Cluster.join(n1, n3)
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n1, n2, n3]) == [["303"], ["303"], ["303"]]
    end)
  end

  test "counterexample 4" do
    [n1, n2, n3] = Cluster.start(3)

    Cluster.split(n3, n2)
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n3, n2, n1]) == [[], [], []]
    end)

    Cluster.connect(n1, ids(1001..1100))
    Cluster.connect(n2, ids(2001..2100))
    Cluster.connect(n3, ids(3001..3100))
    all = ids(1001..1100) ++ ids(2001..2100) ++ ids(3001..3100)
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n1, n2, n3]) ==
        [all, ids(1001..1100)++ids(2001..2100), ids(1001..1100)++ids(3001..3100)]
    end)

    Cluster.disconnect(ids(1001..1050) ++ ids(2001..2050) ++ ids(3001..3050))
    all = ids(1051..1100) ++ ids(2051..2100) ++ ids(3051..3100)
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n1, n2, n3]) ==
        [all, ids(1051..1100)++ids(2051..2100), ids(1051..1100)++ids(3051..3100)]
    end)

    Cluster.stop_node(n1)
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n2, n3]) ==
        [ids(2051..2100), ids(3051..3100)]
    end)

    Cluster.connect(n2, ids(2101..2200))
    Cluster.connect(n3, ids(3101..3200))
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n2, n3]) ==
        [ids(2051..2200), ids(3051..3200)]
    end)

    Cluster.connect(n2, ids(2201..2300))
    Cluster.connect(n3, ids(3201..3300))
    assert eventually(fn ->
      Cluster.session_ids_on_nodes([n2, n3]) ==
        [ids(2051..2300), ids(3051..3300)]
    end)

    Cluster.connect(n2, ids(2301..2400))
    Cluster.connect(n3, ids(3301..3400))
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n2, n3]) ==
        [ids(2051..2400), ids(3051..3400)]
    end)

    all = ids(2051..2400) ++ ids(3051..3400)
    Cluster.join(n3, n2)
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n2, n3]) == [all, all]
    end, 60, 1_000)
  end

  test "counterexample 5" do
    [n1, n2, n3] = Cluster.start(3)

    Cluster.split(n2, n3)
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n1, n2, n3]) == [[], [], []]
    end)

    Cluster.stop_node(n3)
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n1, n2]) == [[], []]
    end)

    Cluster.start_node(n3)
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n1, n2, n3]) == [[], [], []]
    end)

    Cluster.connect(n1, ids(101..110))
    Cluster.connect(n2, ids(201..210))
    Cluster.connect(n3, ids(301..310))

    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n1, n2, n3]) ==
        [ids(101..110) ++ ids(201..210) ++ ids(301..310),
         ids(101..110) ++ ids(201..210),
         ids(101..110) ++ ids(301..310)]
    end, 60, 1_000)
  end

  defp ids(range), do: Enum.map(range, &Integer.to_string/1)
end
