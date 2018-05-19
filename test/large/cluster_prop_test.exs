defmodule BreakingPP.Test.ClusterPropTest do
  use ExUnit.Case
  use PropCheck.StateM
  use PropCheck
  import BreakingPP.Test.Eventually
  import BreakingPP.Test.Cluster, only: [session_ids: 1, node_map: 1]
  alias BreakingPP.Test.Cluster

  @cluster_size 3
  @socket_table :sockets

  @type cluster_node :: integer()
  @type session_id :: String.t
  @type session :: {cluster_node(), session_id()}

  @tag timeout: :infinity
  @tag :property
  property "sessions are eventually consistent in a cluster of 3 nodes",
    [:verbose, {:start_size, 10}, {:max_size, 100},
     {:numtests, 500}, {:max_shrinks, 10}] do
      forall cmds in commands(__MODULE__) do
        fresh_socket_table()
        {history, state, result} = run_commands(__MODULE__, cmds)
        (result == :ok)
        |> when_fail(IO.puts """
          History: #{inspect history, pretty: true}
          State: #{inspect state, pretty: true}
          Result: #{inspect result, pretty: true}
          Sessions: #{inspect session_ids_on_nodes(state.running_nodes),
            pretty: true}
          """)
      end
  end

  def start_cluster(size), do: Cluster.cluster_started(size)
  def start_node(node), do: Cluster.node_started(node)
  def stop_node(node), do: Cluster.node_stopped(node)

  def connect_sessions(sessions) do
    sockets = Enum.map(sessions, fn {node, id} ->
      Cluster.session_connected(node_map(node), id)
    end)
    store_sockets(sessions, sockets)
    sessions
  end

  def disconnect_sessions(sessions) do
    take_sockets(sessions)
    |> Enum.map(fn {_, s} -> Cluster.session_disconnected(s) end)
  end

  def command(%{running_nodes: []}) do
    {:call, __MODULE__, :start_cluster, [@cluster_size]}
  end
  def command(st) do
    cmds = [{5, {:call, __MODULE__, :connect_sessions, [sessions(st)]}}]
      ++ maybe_disconnect_sessions(st)
      ++ maybe_start_node(st)
      ++ maybe_stop_node(st)
    weighted_union(cmds)
  end

  defp maybe_disconnect_sessions(%{sessions: []}), do: []
  defp maybe_disconnect_sessions(st) do
    [{5, {:call, __MODULE__, :disconnect_sessions, [existing_sessions(st)]}}]
  end
    
  defp maybe_start_node(%{stopped_nodes: []}), do: []
  defp maybe_start_node(st) do
    [{1, {:call, __MODULE__, :start_node, [stopped_node(st)]}}]
  end

  defp maybe_stop_node(%{running_nodes: []}), do: []
  defp maybe_stop_node(st) do
    [{1, {:call, __MODULE__, :stop_node, [running_node(st)]}}]
  end

  def initial_state, do: %{running_nodes: [], stopped_nodes: [], sessions: []}

  def precondition(s, {:call, __MODULE__, :start_node, [node]}) do
    Enum.member?(s.stopped_nodes, node)
  end
  def precondition(s, {:call, __MODULE__, :stop_node, [node]}) do
    Enum.count(s.running_nodes) > 1 and Enum.member?(s.running_nodes, node)
  end
  def precondition(s, {:call, __MODULE__, :disconnect_sessions, _}) do
    s.sessions != []
  end
  def precondition(_, _), do: true

  def next_state(s, _, {:call, __MODULE__, :start_cluster, [size]}) do
    %{s | running_nodes: Enum.into(1..size, [])}
  end
  def next_state(s, _, {:call, __MODULE__, :start_node, [node]}) do
    %{s | running_nodes: [node|s.running_nodes],
          stopped_nodes: List.delete(s.stopped_nodes, node)}
  end
  def next_state(s, _, {:call, __MODULE__, :stop_node, [node]}) do
    sessions = Enum.reject(s.sessions, fn {n, _} -> n == node end)
    %{s | running_nodes: List.delete(s.running_nodes, node),
          stopped_nodes: [node|s.stopped_nodes],
          sessions: sessions}
  end
  def next_state(s, _,
    {:call, __MODULE__, :connect_sessions, [sessions]}) do
    %{s | sessions: s.sessions ++ sessions}
  end
  def next_state(s, _, {:call, __MODULE__, :disconnect_sessions, [sessions]}) do
    %{s | sessions: s.sessions -- sessions}
  end

  def postcondition(st, {:call, __MODULE__, :start_node, [node]}, _) do
    eventually(fn ->
      sessions_on_nodes_are_equal_to(st.sessions, [node|st.running_nodes])
    end)
  end
  def postcondition(st, {:call, __MODULE__, :stop_node, [node]}, _) do
    sessions = Enum.reject(st.sessions, fn {n, _} -> n == node end)
    eventually(fn ->
      sessions_on_nodes_are_equal_to(
        sessions, List.delete(st.running_nodes, node))
    end)
  end
  def postcondition(st, {:call, __MODULE__, :connect_sessions, [sessions]},_) do
    eventually(fn ->
      sessions_on_nodes_are_equal_to(st.sessions ++ sessions, st.running_nodes)
    end)
  end
  def postcondition(st,{:call,__MODULE__,:disconnect_sessions, [sessions]},_) do
    eventually(fn ->
      sessions_on_nodes_are_equal_to(st.sessions -- sessions, st.running_nodes)
    end)
  end
  def postcondition(_, _, _), do: true

  defp sessions_on_nodes_are_equal_to(sessions, nodes) do
    session_ids = Enum.map(sessions, fn {_, id} -> id end) |> Enum.sort
    Enum.all?(session_ids_on_nodes(nodes),
      fn {_, session_ids_on_node} -> session_ids_on_node == session_ids end)
  end

  defp sessions(st) do
    non_empty(list({running_node(st), session_id()}))
  end

  defp existing_sessions(st) do
    let n <- integer(1, Enum.count(st.sessions)) do
      Enum.take_random(st.sessions, n)
    end
  end

  defp session_id do
    let _ <- integer(), do: "#{System.unique_integer([:monotonic, :positive])}"
  end

  defp running_node(%{running_nodes: nodes}), do: oneof(nodes)
  defp stopped_node(%{stopped_nodes: nodes}), do: oneof(nodes)

  defp session_ids_on_nodes(nodes) do
    Enum.map(nodes, fn n -> {n, session_ids_on(n)} end) |> Enum.into(%{})
  end

  defp session_ids_on(n), do: node_map(n) |> session_ids()

  defp fresh_socket_table do
    try do
      :ets.delete(@socket_table)
    rescue ArgumentError -> :ok
    end
    :ets.new(@socket_table, [:named_table, :public, :set])
  end

  defp store_sockets(sessions, sockets) do
    Enum.zip(sessions, sockets)
    |> Enum.map(fn {s, sckt} -> :ets.insert(@socket_table, {s, sckt}) end)
  end

  defp take_sockets(sessions) do
    Enum.map(sessions, fn s -> :ets.take(@socket_table, s) end)
    |> Enum.concat
  end
end
