defmodule BreakingPP.ClusterJoinLeaveCounterExamplesTest do
  @moduledoc """
  This is a set of found counterexamples related to starting and stopping nodes in the cluster
  and issues with synchronizing state in the cluster after these events.

  Counterexamples from this module have been fixed in this squash-merge commit:
  [e5f3641](https://github.com/phoenixframework/phoenix_pubsub/commit/e5f3641f8b8d076cce5810dd1deb6fc6f868bbf9).
  """
  use ExUnit.Case
  import BreakingPP.Eventually
  alias BreakingPP.RealWorld.Cluster

  @moduletag timeout: 300_000

  @doc """
  Empty deltas were sometimes chosen when extracing newest delta from the state.
  Fixed by [b7170eb](https://github.com/distributed-owls/phoenix_pubsub/commit/b7170eb89fe07627f3081e02f0ff07551df51529).
  """
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

  @doc """
  Delta that dominated on a set of replicas that the other node had no knowledge of was sometimes chosen.
  Fixed with [1b6345c](https://github.com/distributed-owls/phoenix_pubsub/commit/1b6345c2025fcd618f21fd41585cee58d3302fe9).
  """
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
