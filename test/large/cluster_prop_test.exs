defmodule BreakingPP.Test.ClusterPropTest do
  use ExUnit.Case
  use PropCheck.StateM
  use PropCheck
  import BreakingPP.Eventually
  alias BreakingPP.{RealWorld, Model}

  @cluster_size 7

  @tag timeout: :infinity
  @tag :property
  property "sessions are eventually consistent in a cluster of 7 nodes",
    [:verbose, {:start_size, 1}, {:max_size, 50},
     {:numtests, 1_000}, {:max_shrinks, 1_000}] do
      forall cmds in commands(__MODULE__) do
        {history, state, result} = run_commands(__MODULE__, cmds)
        (result == :ok)
        |> collect(session_count_range(state, 100))
        |> when_fail(IO.puts """
          History: #{inspect history, pretty: true, limit: :infinity}
          State: #{inspect state, pretty: true, limit: :infinity}
          Result: #{inspect result, pretty: true, limit: :infinity}
          Sessions: #{inspect Model.Cluster.sessions(state), pretty: true, limit: :infinity}
          Sessions on nodes: #{inspect(
             Model.Cluster.started_nodes(state)
             |> Enum.map(&Model.Node.id/1)
             |> RealWorld.Cluster.session_ids_on_nodes(), pretty: true, limit: :infinity)}
          """)
      end
  end

  def start_cluster(size), do: RealWorld.Cluster.start(size)

  def start_node(_, node) do
    Model.Node.id(node) |> RealWorld.Cluster.start_node()
  end

  def stop_node(_, node) do
    Model.Node.id(node) |> RealWorld.Cluster.stop_node()
  end

  def join(_, node1, node2) do
    RealWorld.Cluster.join(Model.Node.id(node1), Model.Node.id(node2))
  end

  def split(_, node1, node2) do
    RealWorld.Cluster.split(Model.Node.id(node1), Model.Node.id(node2))
  end

  def connect_sessions(_, sessions) do
    Enum.group_by(sessions, &Model.Session.node/1)
    |> Enum.map(fn {node, sessions} ->
      ids = Enum.map(sessions, &Model.Session.id/1)
      RealWorld.Cluster.connect(Model.Node.id(node), ids)
    end)
  end

  def disconnect_sessions(_, sessions) do
    Enum.map(sessions, &Model.Session.id/1)
    |> RealWorld.Cluster.disconnect()
  end

  def command(st) do
    case Model.Cluster.started_nodes(st) do
      [] ->
        {:call, __MODULE__, :start_cluster, [@cluster_size]}
      _ ->
        cmds = [{5, {:call, __MODULE__, :connect_sessions,
              [verify_properties?(), sessions(st)]}}]
        ++ maybe_disconnect_sessions(st)
        ++ maybe_start_node(st)
        ++ maybe_stop_node(st)
        ++ maybe_split_nodes(st)
        ++ maybe_join_nodes(st)
        weighted_union(cmds)
    end
  end

  defp maybe_split_nodes(st) do
    case Model.Cluster.started_nodes(st) do
      [] ->
        []
      _ ->
        [{1, {:call, __MODULE__, :split,
              [verify_properties?(), running_node(st), running_node(st)]}}]
    end
  end

  defp maybe_join_nodes(st) do
    case Model.Cluster.started_nodes(st) do
      [] ->
        []
      _ ->
        [{1, {:call, __MODULE__, :join,
              [verify_properties?(), running_node(st), running_node(st)]}}]
    end
  end

  defp maybe_disconnect_sessions(st) do
    case Model.Cluster.sessions(st) do
      [] ->
        []
      _ ->
        [{5, {:call, __MODULE__, :disconnect_sessions,
              [verify_properties?(), existing_sessions(st)]}}]
    end
  end

  defp maybe_start_node(st) do
    case Model.Cluster.stopped_nodes(st) do
      [] ->
        []
      _ ->
        [{1, {:call, __MODULE__, :start_node,
              [verify_properties?(), stopped_node(st)]}}]
    end
  end

  defp maybe_stop_node(st) do
    case Model.Cluster.started_nodes(st) do
      [] ->
        []
      _ ->
        [{1, {:call, __MODULE__, :stop_node,
              [verify_properties?(), running_node(st)]}}]
    end
  end

  def initial_state do
    Model.Cluster.new()
  end

  def precondition(st, {:call, __MODULE__, :start_cluster, _}) do
    Model.Cluster.started_nodes(st) == [] and
    Model.Cluster.stopped_nodes(st) == []
  end
  def precondition(st, {:call, __MODULE__, :connect_sessions, [_, sessions]}) do
    Enum.all?(sessions, fn s ->
      n = Model.Session.node(s)
      Model.Cluster.node_started?(st, n)
    end)
  end
  def precondition(s, {:call, __MODULE__, :disconnect_sessions, [_, sessions]}) do
    (sessions -- Model.Cluster.sessions(s)) == []
  end
  def precondition(s, {:call, __MODULE__, :start_node, [_, node]}) do
    Model.Cluster.node_stopped?(s, node)
  end
  def precondition(s, {:call, __MODULE__, :stop_node, [_, node]}) do
    Model.Cluster.node_started?(s, node) and
    Enum.count(Model.Cluster.started_nodes(s)) > 1
  end
  def precondition(s, {:call, __MODULE__, :split, [_, node1, node2]}) do
    node1 != node2 and not Model.Cluster.split_between?(s, node1, node2)
  end
  def precondition(s, {:call, __MODULE__, :join, [_, node1, node2]}) do
    Model.Cluster.split_between?(s, node1, node2)
  end

  def next_state(s, _, {:call, __MODULE__, :start_cluster, [size]}) do
    Model.Cluster.start_nodes(s, Enum.map(1..size, &Model.Node.new/1))
  end
  def next_state(s, _, {:call, __MODULE__, :start_node, [_, node]}) do
    Model.Cluster.start_node(s, node)
  end
  def next_state(s, _, {:call, __MODULE__, :stop_node, [_, node]}) do
    Model.Cluster.stop_node(s, node)
  end
  def next_state(s, _, {:call, __MODULE__, :connect_sessions, [_, sessions]}) do
    Model.Cluster.add_sessions(s, sessions)
  end
  def next_state(s, _, {:call, __MODULE__, :disconnect_sessions, [_, sessions]}) do
    Model.Cluster.remove_sessions(s, sessions)
  end
  def next_state(s, _, {:call, __MODULE__, :split, [_, node1, node2]}) do
    Model.Cluster.split(s, node1, node2)
  end
  def next_state(s, _, {:call, __MODULE__, :join, [_, node1, node2]}) do
    Model.Cluster.join(s, node1, node2)
  end

  def postcondition(st, {:call, __MODULE__, :start_node, [:verify, node]}, _) do
    eventually(fn ->
      sessions_in_real_world_are_equal_to(Model.Cluster.start_node(st, node))
    end)
  end
  def postcondition(st, {:call, __MODULE__, :stop_node, [:verify, node]}, _) do
    eventually(fn ->
        sessions_in_real_world_are_equal_to(Model.Cluster.stop_node(st, node))
    end)
  end
  def postcondition(st, {:call, __MODULE__, :connect_sessions, [:verify, ss]},_) do
    eventually(fn ->
      sessions_in_real_world_are_equal_to(Model.Cluster.add_sessions(st, ss))
    end)
  end
  def postcondition(st,{:call,__MODULE__,:disconnect_sessions, [:verify, ss]},_) do
    eventually(fn ->
      sessions_in_real_world_are_equal_to(Model.Cluster.remove_sessions(st, ss))
    end)
  end
  def postcondition(st, {:call, __MODULE__, :join, [:verify, n1, n2]}, _) do
    eventually(fn ->
      sessions_in_real_world_are_equal_to(Model.Cluster.join(st, n1, n2))
    end)
  end
  def postcondition(st, {:call, __MODULE__, :split, [:verify, n1, n2]}, _) do
    eventually(fn ->
      sessions_in_real_world_are_equal_to(Model.Cluster.split(st, n1, n2))
    end)
  end
  def postcondition(_, {:call, __MODULE__, :start_cluster, _}, _) do
    true
  end
  def postcondition(_, {:call, __MODULE__, _, [:dont_verify | _]}, _) do
    true
  end

  defp sessions_in_real_world_are_equal_to(cluster) do
    Model.Cluster.started_nodes(cluster)
    |> Enum.all?(fn n ->
      session_ids_in_real_world =
        Model.Node.id(n)
        |> RealWorld.Cluster.session_ids()
        |> Enum.sort()

      session_ids_in_model =
        Model.Cluster.sessions(cluster, n)
        |> Enum.map(&Model.Session.id/1)
        |> Enum.sort()

      session_ids_in_real_world == session_ids_in_model
    end)
  end

  defp verify_properties? do
    weighted_union([{1, :verify}, {3, :dont_verify}])
  end

  defp sessions(st) do
    sized(size,
      resize(size * 5,
        non_empty(list(session(st)))))
  end

  defp session(st) do
    let node <- running_node(st) do
      let id <- session_id(node) do
        Model.Session.new(node, id)
      end
    end
  end

  defp existing_sessions(st) do
    let n <- integer(1, Enum.count(Model.Cluster.sessions(st))) do
      Enum.take_random(Model.Cluster.sessions(st), n)
    end
  end

  defp session_id(node) do
    node_prefix = Model.Node.id(node) * 1_000_000
    let _ <- integer() do
      "#{node_prefix + System.unique_integer([:monotonic, :positive])}"
    end
  end

  defp running_node(state), do: oneof(Model.Cluster.started_nodes(state))
  defp stopped_node(state), do: oneof(Model.Cluster.stopped_nodes(state))

  defp session_count_range(state, range_size) do
    session_count = Model.Cluster.sessions(state) |> Enum.count
    lower_bound = div(session_count, range_size) * range_size
    upper_bound = lower_bound + range_size - 1
    {lower_bound, upper_bound}
  end

end
