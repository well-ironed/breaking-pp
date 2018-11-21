defmodule BreakingPP.ClusterNetsplitCounterExamplesTest do
  @moduledoc """
  This is a set of found counterexamples related to starting and stopping nodes in the cluster
  and issues with synchronizing state in the cluster after these events.

  Counterexamples from this module have been fixed in this squash-merge commit:
  [cc6d675](https://github.com/phoenixframework/phoenix_pubsub/commit/cc6d675269d304d2f8015be5d285e42631b421bf).
  """
  use ExUnit.Case
  import BreakingPP.Eventually
  alias BreakingPP.RealWorld.Cluster

  @moduletag timeout: 300_000

  @doc """
  Session joins were observed via netsplit, but removes were not.
  Fixed with [b612985](https://github.com/distributed-owls/phoenix_pubsub/commit/b612985a276ccf8fffda6cc55d7aa2eb0cd503da).
  """
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

  @doc """
  Non-contiguous deltas could have been merged into one.
  I.e. merge([a,b], [c,d]) where c > d resulted in [a,d].
  Fixed with [57dd84e](https://github.com/distributed-owls/phoenix_pubsub/commit/57dd84eacb3721e7bec96843b2c22258387194a0).
  """
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

  @doc """
  Automatic attempt to connect to another node inside Erlang VM when sending messages
  was causing the Tracker processes to stall.

  Fixed via `kernel` configuration with [18f310a](https://github.com/distributed-owls/breaking-pp/commit/18f310a8200fa965325b1e16633cc00b4071fbef).
  """
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

  @doc """
  Not pruning context together with clouds when extracting a delta caused incorrect cluster sync.
  Fixed with [b0a913c](https://github.com/distributed-owls/phoenix_pubsub/commit/b0a913ca86e658b023014cd18576124e68c3a6cd).
  """
  test "counterexample 6" do
    [n1, n2, n3, n4, n5, n6, n7] = Cluster.start(7)

    Cluster.connect(n1, ids(100..199))
    Cluster.connect(n2, ids(200..299))
    Cluster.connect(n3, ids(300..399))
    Cluster.connect(n4, ids(400..499))
    Cluster.connect(n5, ids(500..599))
    Cluster.connect(n6, ids(600..699))
    Cluster.connect(n7, ids(700..799))
    all = ids(100..199) ++ ids(200..299) ++ ids(300..399) ++ ids(400..499)
      ++ ids(500..599) ++ ids(600..699) ++ ids(700..799)

    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([n7, n6, n5, n4, n3, n2, n1]) ==
        List.duplicate(all, 7)
    end)
  end

  defp ids(range), do: Enum.map(range, &Integer.to_string/1)
end
