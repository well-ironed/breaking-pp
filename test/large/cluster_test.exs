defmodule BreakingPP.Test.ClusterTest do
  use ExUnit.Case
  import BreakingPP.Eventually
  alias BreakingPP.RealWorld.Cluster

  test "active sessions are replicated in the cluster" do
    # given
    [n1, n2] = Cluster.start(2)
    # when
    Cluster.connect(n1, ["1"])
    Cluster.connect(n2, ["2"])
    # then 
    assert eventually(fn -> Cluster.session_ids(n2) == ["1", "2"] end)
    assert eventually(fn -> Cluster.session_ids(n1) == ["1", "2"] end)
  end

  test "closed sessions are replicated in the cluster" do
    # given
    [n1, n2] = Cluster.start(2)
    Cluster.connect(n1, ["1"])
    true = eventually(fn -> Cluster.session_ids(n2) == ["1"] end)
    # when
    Cluster.disconnect(["1"])
    # then
    assert eventually(fn -> Cluster.session_ids(n1) == [] end)
  end

  test "sessions from stopped nodes don't longer appear on running nodes" do
    # given
    [n1, n2] = Cluster.start(2)
    Cluster.connect(n1, ["1"])
    Cluster.connect(n2, ["2"])
    true = eventually(fn -> Cluster.session_ids(n1) == ["1", "2"] end)
    # when
    Cluster.stop_node(n2)
    # then
    assert eventually(fn -> Cluster.session_ids(n1) == ["1"] end)
  end

  test "sessions are replicated again to a restarted node" do
    # given
    [n1, n2] = Cluster.start(2)
    Cluster.connect(n1, ["1"])
    true = eventually(fn -> Cluster.session_ids(n2) == ["1"] end)
    # when
    Cluster.stop_node(n2)
    Cluster.start_node(n2)
    # then
    assert eventually(fn -> Cluster.session_ids(n2) == ["1"] end)
  end
end
