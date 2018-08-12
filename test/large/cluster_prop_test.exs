defmodule BreakingPP.Test.ClusterPropTest do
  use ExUnit.Case
  use PropCheck.StateM
  use PropCheck
  import BreakingPP.Test.Eventually
  import BreakingPP.Test.Cluster, only: [session_ids: 1, n: 1]
  alias BreakingPP.Test.{Cluster, Session, SessionStore}

  @cluster_size 3

  @type cluster_node :: integer()
  @type session_id :: String.t
  @type session :: {cluster_node(), session_id()}

  @tag timeout: :infinity
  @tag :property
  property "sessions are eventually consistent in a cluster of 3 nodes",
    [:verbose, {:start_size, 1}, {:max_size, 50},
     {:numtests, 10}, {:max_shrinks, 100}] do
      forall cmds in commands(__MODULE__) do
        SessionStore.new
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

  def start_cluster(size), do: Cluster.start(size)
  def start_node(node), do: Cluster.start_node(node)
  def stop_node(node), do: Cluster.stop_node(node)

  def connect_sessions(nodes_ids) do
    sessions = Enum.map(nodes_ids, fn {n, id} -> Session.connect(n, id) end)
    SessionStore.store(ids(nodes_ids), sessions)
    sessions
  end

  def disconnect_sessions(nodes_ids) do
    SessionStore.take(ids(nodes_ids))
    |> Enum.map(fn s -> Session.disconnect(s) end)
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
    %{s | running_nodes: Enum.map(1..size, fn id -> n(id) end)}
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
    sized(size,
      resize(size * 5,
        non_empty(list({running_node(st), session_id()}))))
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
    Enum.map(nodes, fn n -> {n, session_ids(n)} end) |> Enum.into(%{})
  end

  defp ids(nodes_ids), do: Enum.map(nodes_ids, fn {_, id} -> id end)
end
