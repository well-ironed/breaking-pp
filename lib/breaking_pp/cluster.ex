defmodule BreakingPP.Cluster do
  use GenServer

  def start_link, do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def init([]) do
    nodes = System.get_env("BREAKING_PP_CLUSTER") |> parse_nodes()
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
    Process.send_after(self(), :connect, 5_000)
  end

  defp connect_nodes(nodes) do
    Enum.each(nodes, &Node.connect/1)
  end

  defp parse_nodes(nil), do: []
  defp parse_nodes(nodes) do
    String.split(nodes, ",", trim: true)
    |> Enum.map(&String.to_atom/1)
  end
end
