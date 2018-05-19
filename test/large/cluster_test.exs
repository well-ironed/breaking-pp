defmodule BreakingPP.Test.ClusterTest do
  use ExUnit.Case
  import BreakingPP.Test.{Cluster, Eventually}

  test "active sessions are replicated in the cluster" do
    # given
    [n1, n2] = cluster_started(2)
    # when
    session_connected(n1, "1")
    session_connected(n2, "2")
    # then 
    assert eventually(fn -> session_ids(n2) == ["1", "2"] end)
    assert eventually(fn -> session_ids(n1) == ["1", "2"] end)
  end

  test "closed sessions are replicated in the cluster" do
    # given
    [n1, n2] = cluster_started(2)
    s = session_connected(n1, "1")
    true = eventually(fn -> session_ids(n2) == ["1"] end)
    # when
    session_disconnected(s)
    # then
    assert eventually(fn -> session_ids(n2) == [] end)
  end

  test "sessions from stopped nodes don't longer appear on running nodes" do
    # given
    [n1, n2] = cluster_started(2)
    session_connected(n1, "1")
    session_connected(n2, "2")
    true = eventually(fn -> session_ids(n1) == ["1", "2"] end)
    # when
    node_stopped(2)
    # then
    assert eventually(fn -> session_ids(n1) == ["1"] end)
  end

  test "sessions are replicated again to a restarted node" do
    # given
    [n1, n2] = cluster_started(2)
    session_connected(n1, "1")
    true = eventually(fn -> session_ids(n2) == ["1"] end)
    # when
    node_stopped(2)
    node_started(2)
    # then
    assert eventually(fn -> session_ids(n2) == ["1"] end)
  end
end
