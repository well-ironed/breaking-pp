defmodule BreakingPP.RealWorld.Cluster do
  import BreakingPP.Eventually
  alias BreakingPP.RealWorld
  alias BreakingPP.RealWorld.Sessions

  def start(size) do
    reset_splits()
    Sessions.new()
    {_, 0} = cmd(["stop_cluster"])
    {_, 0} = cmd(["create_network"])

    1..size
    |> Enum.map(&Task.async(fn -> create_node(&1, size) end))
    |> Enum.map(&Task.await(&1, 60_000))
  end

  defp create_node(node_id, cluster_size) do
    {_, 0} = cmd(["create_node", "#{node_id} #{cluster_size}"])
    true = wait_for_node(node_id)
    node_id
  end

  def start_node(node_id) do
    {_, 0} = cmd(["start_node", "#{node_id}"])
    true = wait_for_node(node_id)
  end

  def stop_node(node_id) do
    {_, 0} = cmd(["stop_node", "#{node_id}"])
  end

  def connect(node_id, session_ids) do
    n = real_world_node(node_id)
    Sessions.connect(n, session_ids)
  end

  def disconnect(session_ids) do
    Sessions.disconnect(session_ids)
  end

  def split(node1_id, node2_id) do
    {_, 0} = cmd(["split", "#{node1_id}", "#{node2_id}"])
  end

  def join(node1_id, node2_id) do
    {_, 0} = cmd(["join", "#{node1_id}", "#{node2_id}"])
  end

  def session_ids_on_nodes(node_ids) do
    Enum.map(node_ids, &session_ids/1)
  end

  def session_ids(node_id) do
    n = real_world_node(node_id)
    url = "http://#{RealWorld.Node.host(n)}:#{RealWorld.Node.port(n)}/sessions"
    r = HTTPoison.get!(url)
    Poison.decode!(r.body) |> Enum.sort
  end

  defp wait_for_node(node_id) do
    n = real_world_node(node_id)
    url = "http://#{RealWorld.Node.host(n)}:#{RealWorld.Node.port(n)}/status"
    eventually(fn ->
      case HTTPoison.get(url, []) do
        {:ok, r} -> r.status_code == 200
        _ -> false
      end
    end)
  end

  defp real_world_node(id) do
    {ip, 0} = cmd(["node_ip", "#{id}"])
    ip = String.trim(ip)
    RealWorld.Node.new(id, ip)
  end

  defp reset_splits do
    {_, 0} = cmd(["reset_splits"])
  end

  defp cmd(cmd) do
    path = Path.join([File.cwd!, "priv", "cluster.sh"])
    System.cmd(path, cmd, stderr_to_stdout: true)
  end

end
