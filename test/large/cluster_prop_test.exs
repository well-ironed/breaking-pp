defmodule BreakingPP.Test.ClusterPropTest do
  use ExUnit.Case
  use PropCheck.StateM
  use PropCheck
  import BreakingPP.Test.Eventually
  import BreakingPP.Test.Cluster, only: [sessions: 1, node_map: 1]
  alias BreakingPP.Test.Cluster

  @cluster_size 3

  @tag timeout: :infinity
  property "sessions are eventually consistent in a cluster of 3 nodes",
    [:verbose, {:numtests, 1000}, {:start_size, 10}, {:max_size, 1000}] do
      forall cmds in commands(__MODULE__) do
        {history, state, result} = run_commands(__MODULE__, cmds)
        (result == :ok)
        |> when_fail(IO.puts """
          History: #{inspect history, pretty: true}
          State: #{inspect state, pretty: true}
          Result: #{inspect result, pretty: true}
          Sessions on nodes: #{inspect sessions_on_nodes(state), pretty: true}
          """)
      end
  end

  def start_cluster(size), do: Cluster.cluster_started(size)

  def connect_session(node, id) do
    Cluster.session_connected(node_map(node), id)
  end

  def disconnect_session(_node, _id, socket) do
    Cluster.session_disconnected(socket)
  end

  def command(%{nodes: []}) do
    {:call, __MODULE__, :start_cluster, [@cluster_size]}
  end
  def command(%{sessions: []}=st) do
    {:call, __MODULE__, :connect_session, [cluster_node(st), session_id()]}
  end
  def command(st) do
    oneof([
      {:call, __MODULE__, :connect_session, [cluster_node(st), session_id()]},
      {:call, __MODULE__, :disconnect_session, disconnect_args(st)}
    ])
  end

  def initial_state, do: %{nodes: [], sessions: []}

  def next_state(s, _, {:call, __MODULE__, :start_cluster, [size]}) do
    %{s | nodes: Enum.into(1..size, [])}
  end
  def next_state(s, sckt, {:call, __MODULE__, :connect_session, [node, id]}) do
    %{s | sessions: [{id, node, sckt} | s.sessions]}
  end
  def next_state(s, _,
    {:call, __MODULE__, :disconnect_session, [node, id, socket]}) do
    %{s | sessions: 
      Enum.reject(s.sessions, fn s -> s == {id, node, socket} end)}
  end

  def precondition(s, {:call, __MODULE__, :disconnect_session, _}) do
    s.sessions != []
  end
  def precondition(_, _), do: true

  def postcondition(_, {:call, __MODULE__, :connect_session, [node, id]}, _) do
    eventually(fn -> Enum.member?(sessions_on_node(node), id) end)
  end
  def postcondition(_,
    {:call, __MODULE__, :disconnect_session, [node, id, _]}, _) do
    eventually(fn -> not Enum.member?(sessions_on_node(node), id) end)
  end
  def postcondition(_, _, _), do: true

  defp session_id do
    let _ <- integer(), do: "#{System.unique_integer([:monotonic, :positive])}"
  end

  defp disconnect_args(%{sessions: sessions}) do
    let {id, node, socket} <- oneof(sessions), do: [node, id, socket]
  end

  defp cluster_node(%{nodes: nodes}), do: oneof(nodes)

  defp sessions_on_nodes(%{nodes: nodes}) do
    Enum.map(nodes, fn n -> {n, sessions_on_node(n)} end)
    |> Enum.into(%{})
  end

  defp sessions_on_node(n), do: node_map(n) |> sessions()
end
