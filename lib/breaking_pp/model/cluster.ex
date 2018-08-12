defmodule BreakingPP.Model.Cluster do
  alias BreakingPP.Model.{Node, Session}

  defstruct [started_nodes: [], stopped_nodes: [], sessions: []]

  @type session_id :: {Node.t, String.t}

  @type t :: %__MODULE__{
    started_nodes: [Node.t],
    stopped_nodes: [Node.t],
    sessions: [Session.t]}

  def new, do: %__MODULE__{}

  def started_nodes(%__MODULE__{started_nodes: ns}), do: ns

  def stopped_nodes(%__MODULE__{stopped_nodes: ns}), do: ns

  def sessions(%__MODULE__{sessions: sessions}), do: sessions

  def start_node(%__MODULE__{}=cluster, node) do
    start_nodes(cluster, [node])
  end

  def start_nodes(%__MODULE__{}=cluster, nodes) do
    %{cluster |
      started_nodes: nodes ++ cluster.started_nodes,
      stopped_nodes: cluster.stopped_nodes -- nodes
     }
  end

  def stop_node(%__MODULE__{}=cluster, node) do
    %{cluster |
      stopped_nodes: [node|cluster.stopped_nodes],
      started_nodes: List.delete(cluster.started_nodes, node),
      sessions:
        Enum.reject(cluster.sessions, fn s -> Session.node(s) == node end)
     }
  end

  def add_sessions(%__MODULE__{}=cluster, sessions) do
    %{cluster | sessions: sessions ++ cluster.sessions}
  end

  def remove_sessions(%__MODULE__{}=cluster, sessions) do
    %{cluster | sessions: cluster.sessions -- sessions}
  end

  def node_stopped?(%__MODULE__{stopped_nodes: ns}, node) do
    Enum.member?(ns, node)
  end

  def node_started?(%__MODULE__{started_nodes: ns}, node) do
    Enum.member?(ns, node)
  end
end
