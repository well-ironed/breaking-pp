defmodule BreakingPP.Test.ClusterPropTest do
  use ExUnit.Case
  use PropCheck.StateM
  use PropCheck
  import BreakingPP.Eventually
  alias BreakingPP.{RealWorld, Model}

  @cluster_size 3

  @tag timeout: :infinity
  @tag :property
  property "sessions are eventually consistent in a cluster of 3 nodes",
    [:verbose, {:start_size, 1}, {:max_size, 50},
     {:numtests, 1_000}, {:max_shrinks, 100}] do
      forall cmds in commands(__MODULE__) do
        {history, state, result} = run_commands(__MODULE__, cmds)
        (result == :ok)
        |> when_fail(IO.puts """
          History: #{inspect history, pretty: true}
          State: #{inspect state, pretty: true}
          Result: #{inspect result, pretty: true}
          Sessions: #{inspect Model.Cluster.sessions(state), pretty: true}
          """)
      end
  end

  def start_cluster(size), do: RealWorld.Cluster.start(size)

  def start_node(node) do
    Model.Node.id(node) |> RealWorld.Cluster.start_node()
  end

  def stop_node(node) do
    Model.Node.id(node) |> RealWorld.Cluster.stop_node()
  end

  def connect_sessions(sessions) do
    Enum.group_by(sessions, &Model.Session.node/1)
    |> Enum.map(fn {node, sessions} ->
      ids = Enum.map(sessions, &Model.Session.id/1)
      RealWorld.Cluster.connect(Model.Node.id(node), ids)
    end)
  end

  def disconnect_sessions(sessions) do
    Enum.map(sessions, &Model.Session.id/1)
    |> RealWorld.Cluster.disconnect()
  end

  def command(st) do
    case Model.Cluster.started_nodes(st) do
      [] ->
        {:call, __MODULE__, :start_cluster, [@cluster_size]}
      _ ->
        cmds = [{5, {:call, __MODULE__, :connect_sessions, [sessions(st)]}}]
          ++ maybe_disconnect_sessions(st)
          ++ maybe_start_node(st)
          ++ maybe_stop_node(st)
          ++ maybe_split_nodes(st)
          ++ maybe_join_nodes(st)
        weighted_union(cmds)
    end
  end

  defp maybe_split_nodes(_st) do
    IO.puts "would split nodes"
    []
  end

  defp maybe_join_nodes(_st) do
    IO.puts "would join nodes"
    []
  end

  defp maybe_disconnect_sessions(st) do
    case Model.Cluster.sessions(st) do
      [] -> []
      _ -> [{5,{:call,__MODULE__,:disconnect_sessions,[existing_sessions(st)]}}]
    end
  end

  defp maybe_start_node(st) do
    case Model.Cluster.stopped_nodes(st) do
      [] -> []
      _ -> [{1, {:call, __MODULE__, :start_node, [stopped_node(st)]}}]
    end
  end

  defp maybe_stop_node(st) do
    case Model.Cluster.started_nodes(st) do
      [] -> []
      _ -> [{1, {:call, __MODULE__, :stop_node, [running_node(st)]}}]
    end
  end

  def initial_state do
    Model.Cluster.new()
  end

  def precondition(s, {:call, __MODULE__, :start_node, [node]}) do
    Model.Cluster.node_stopped?(s, node)
  end
  def precondition(s, {:call, __MODULE__, :stop_node, [node]}) do
    Model.Cluster.node_started?(s, node)
  end
  def precondition(s, {:call, __MODULE__, :disconnect_sessions, _}) do
    Model.Cluster.sessions(s) != []
  end
  def precondition(_, _), do: true

  def next_state(s, _, {:call, __MODULE__, :start_cluster, [size]}) do
    Model.Cluster.start_nodes(s, Enum.map(1..size, &Model.Node.new/1))
  end
  def next_state(s, _, {:call, __MODULE__, :start_node, [node]}) do
    Model.Cluster.start_node(s, node)
  end
  def next_state(s, _, {:call, __MODULE__, :stop_node, [node]}) do
    Model.Cluster.stop_node(s, node)
  end
  def next_state(s, _, {:call, __MODULE__, :connect_sessions, [sessions]}) do
    Model.Cluster.add_sessions(s, sessions)
  end
  def next_state(s, _, {:call, __MODULE__, :disconnect_sessions, [sessions]}) do
    Model.Cluster.remove_sessions(s, sessions)
  end

  def postcondition(st, {:call, __MODULE__, :start_node, [node]}, _) do
    eventually(fn ->
      sessions_in_real_world_are_equal_to(Model.Cluster.start_node(st, node))
    end)
  end
  def postcondition(st, {:call, __MODULE__, :stop_node, [node]}, _) do
    eventually(fn ->
      sessions_in_real_world_are_equal_to(Model.Cluster.stop_node(st, node))
    end)
  end
  def postcondition(st, {:call, __MODULE__, :connect_sessions, [ss]},_) do
    eventually(fn ->
      sessions_in_real_world_are_equal_to(Model.Cluster.add_sessions(st, ss))
    end)
  end
  def postcondition(st,{:call,__MODULE__,:disconnect_sessions, [ss]},_) do
    eventually(fn ->
      sessions_in_real_world_are_equal_to(Model.Cluster.remove_sessions(st, ss))
    end)
  end
  def postcondition(_, _, _), do: true

  defp sessions_in_real_world_are_equal_to(cluster) do
    session_ids_in_real_world =
      Enum.map(Model.Cluster.started_nodes(cluster), &Model.Node.id/1)
      |> RealWorld.Cluster.session_ids_on_nodes()

    session_ids_in_model =
      Enum.map(Model.Cluster.sessions(cluster), &Model.Session.id/1)

    Enum.all?(session_ids_in_real_world, fn session_ids ->
      Enum.sort(session_ids) == Enum.sort(session_ids_in_model)
    end)
  end

  defp sessions(st) do
    sized(size,
      resize(size * 5,
        non_empty(list(session(st)))))
  end

  defp session(st) do
    let {node, id} <- {running_node(st), session_id()} do
      Model.Session.new(node, id)
    end
  end

  defp existing_sessions(st) do
    let n <- integer(1, Enum.count(Model.Cluster.sessions(st))) do
      Enum.take_random(Model.Cluster.sessions(st), n)
    end
  end

  defp session_id do
    let _ <- integer(), do: "#{System.unique_integer([:monotonic, :positive])}"
  end

  defp running_node(state), do: oneof(Model.Cluster.started_nodes(state))
  defp stopped_node(state), do: oneof(Model.Cluster.stopped_nodes(state))
end
