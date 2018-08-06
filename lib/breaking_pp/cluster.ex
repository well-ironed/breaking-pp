defmodule BreakingPP.Cluster do
  use GenServer

  @connect_interval 5_000
  @nodes_env_var "BREAKING_PP_CLUSTER"

  def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    nodes = System.get_env(@nodes_env_var) |> parse_nodes()
    connect_nodes(nodes)
    schedule_connect()
    {:ok, nodes}
  end

  def handle_info(:connect, nodes) do
    connect_nodes(nodes)
    schedule_connect()
    {:noreply, nodes}
  end

  defp schedule_connect do
    Process.send_after(self(), :connect, @connect_interval)
  end

  defp connect_nodes(nodes) do
    Enum.each(nodes, &Node.connect/1)
    BreakingPP.Tracker.sync_with(nodes)
  end

  defp parse_nodes(nil), do: []
  defp parse_nodes(nodes) do
    String.split(nodes, ",", trim: true)
    |> Enum.map(&String.to_atom/1)
  end
end
