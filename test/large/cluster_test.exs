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
    assert eventually(fn -> sessions(n2) == ["1", "2"] end)
    assert eventually(fn -> sessions(n1) == ["1", "2"] end)
  end

  test "closed sessions are replicated in the cluster" do
    # given
    [n1, n2] = cluster_started(2)
    # when
    s = session_connected(n1, "1")
    true = eventually(fn -> sessions(n2) == ["1"] end)
    session_disconnected(s)
    # then
    assert eventually(fn -> sessions(n2) == [] end)
  end
end
