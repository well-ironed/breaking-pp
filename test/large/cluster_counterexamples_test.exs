defmodule BreakingPP.CounterExamplesTest do
  use ExUnit.Case
  import BreakingPP.Test.{Cluster, Eventually}

  @tag timeout: 300_000
  test "counterexample 1" do
    [n1, n2, n3] = cluster_started(3)
    sessions1 = connect_sessions(
      [{n1, "101"}] ++ Enum.map(201..252, fn i -> {n2, "#{i}"} end))
    assert eventually(fn ->
      session_ids_on_nodes_are_equal_to(sessions1, [n1, n2, n3])
    end)

    node_stopped(n3)
    sessions2 = sessions_without_node(sessions1, n3)
    assert eventually(fn ->
      session_ids_on_nodes_are_equal_to(sessions2, [n1, n2])
    end)

    sessions3 = disconnect_sessions(sessions2,
      Enum.map(201..251, fn i -> {2, "#{i}"} end))
    assert eventually(fn ->
      session_ids_on_nodes_are_equal_to(sessions3, [n1, n2])
    end)

    node_stopped(n1)
    sessions4 = sessions_without_node(sessions3, n1)
    assert eventually(fn ->
      session_ids_on_nodes_are_equal_to(sessions4, [n2])
    end)

    node_started(n3)
    assert eventually(fn ->
      session_ids_on_nodes_are_equal_to(sessions4, [n2, n3])
    end, 60, 1_000)
  end

  defp connect_sessions(nodes_ids) do
    Enum.map(nodes_ids, fn {n, id} ->
      {n, id, session_connected(n, id)}
    end)
  end

  defp disconnect_sessions(sessions, disconnect_nodes_ids) do
    Enum.flat_map(sessions, fn {n, id, socket} ->
      case Enum.member?(disconnect_nodes_ids, {n, id}) do
        true ->
          session_disconnected(socket)
          []
        false ->
          [{n, id, socket}]
      end
    end)
  end

  defp session_ids_on_nodes_are_equal_to(sessions, nodes) do
    session_ids = Enum.map(sessions, fn {_, id, _} -> id end) |> Enum.sort
    Enum.all?(nodes, fn n ->
      session_ids(n) == session_ids
    end)
  end

  defp sessions_without_node(sessions, node) do
    Enum.reject(sessions, fn {n, _, _} -> n == node end)
  end
end
