defmodule BreakingPP.Test.ClusterPropTest do
  use ExUnit.Case
  use PropCheck.StateM
  use PropCheck
  import BreakingPP.Test.Eventually
  import BreakingPP.Test.Cluster, only: [sessions: 1, node_map: 1]
  alias BreakingPP.Test.Cluster

  @cluster_size 3
  @socket_table :sockets

  @tag timeout: :infinity
  property "sessions are eventually consistent in a cluster of 3 nodes",
    [:verbose, {:numtests, 100}, {:start_size, 10}, {:max_size, 100}] do
      forall cmds in commands(__MODULE__) do
        fresh_socket_table()
        {history, state, result} = run_commands(__MODULE__, cmds)
        (result == :ok)
        |> when_fail(IO.puts """
          History: #{inspect history, pretty: true}
          State: #{inspect state, pretty: true}
          Result: #{inspect result, pretty: true}
          Sessions on nodes: #{inspect sessions_on_nodes(state.nodes),
            pretty: true}
          """)
      end
  end

  def start_cluster(size), do: Cluster.cluster_started(size)

  def connect_sessions(sessions) do
    sockets = Enum.map(sessions, fn {node, id} ->
      Cluster.session_connected(node_map(node), id)
    end)
    store_sockets(sessions, sockets)
  end

  def disconnect_sessions(sessions) do
    take_sockets(sessions)
    |> Enum.map(fn {_, s} -> Cluster.session_disconnected(s) end)
  end

  def command(%{nodes: []}) do
    {:call, __MODULE__, :start_cluster, [@cluster_size]}
  end
  def command(%{sessions: []}=st) do
    {:call, __MODULE__, :connect_sessions, [new_sessions(st)]}
  end
  def command(st) do
    oneof([
      {:call, __MODULE__, :connect_sessions, [new_sessions(st)]},
      {:call, __MODULE__, :disconnect_sessions, [existing_sessions(st)]}
    ])
  end

  def initial_state, do: %{nodes: [], sessions: []}

  def next_state(s, _, {:call, __MODULE__, :start_cluster, [size]}) do
    %{s | nodes: Enum.into(1..size, [])}
  end
  def next_state(s, _, {:call, __MODULE__, :connect_sessions, [sessions]}) do
    %{s | sessions: s.sessions ++ sessions}
  end
  def next_state(s, _, {:call, __MODULE__, :disconnect_sessions, [sessions]}) do
    %{s | sessions: s.sessions -- sessions}
  end

  def precondition(s, {:call, __MODULE__, :disconnect_sessions, _}) do
    s.sessions != []
  end
  def precondition(_, _), do: true

  def postcondition(st, {:call, __MODULE__, :connect_sessions, [ss]}, _) do
    eventually(fn ->
      sessions_on_all_nodes_are_equal_to(st.sessions ++ ss, st.nodes)
    end)
  end
  def postcondition(st, {:call, __MODULE__, :disconnect_sessions, [ss]},_) do
    eventually(fn ->
      sessions_on_all_nodes_are_equal_to(st.sessions -- ss, st.nodes)
    end)
  end
  def postcondition(_, _, _), do: true

  defp sessions_on_all_nodes_are_equal_to(sessions, nodes) do
    expected_sessions = Enum.map(sessions, fn {_, id} -> id end) |> Enum.sort
    Enum.all?(sessions_on_nodes(nodes),
      fn {_, sessions} -> sessions == expected_sessions end)
  end

  defp new_sessions(st) do
    non_empty(list({cluster_node(st), session_id()}))
  end

  defp existing_sessions(st) do
    let n <- integer(1, Enum.count(st.sessions)) do
      Enum.take_random(st.sessions, n)
    end
  end

  defp session_id do
    let _ <- integer(), do: "#{System.unique_integer([:monotonic, :positive])}"
  end

  defp cluster_node(%{nodes: nodes}), do: oneof(nodes)

  defp sessions_on_nodes(nodes) do
    Enum.map(nodes, fn n -> {n, sessions_on(n)} end) |> Enum.into(%{})
  end

  defp sessions_on(n), do: node_map(n) |> sessions()

  defp fresh_socket_table do
    try do
      :ets.delete(@socket_table)
    rescue ArgumentError -> :ok
    end
    :ets.new(@socket_table, [:named_table, :public, :set])
  end

  defp store_sockets(sessions, sockets) do
    Enum.zip(sessions, sockets)
    |> Enum.map(fn {{_, i}, s} -> :ets.insert(@socket_table, {i, s}) end)
  end

  defp take_sockets(sessions) do
    Enum.map(sessions, fn {_, i} -> :ets.take(@socket_table, i) end)
    |> Enum.concat
  end
end
