defmodule BreakingPP.Test.Cluster do
  import BreakingPP.Test.Eventually
  alias BreakingPP.Model.Node

  def start(size) do
    {_, 0} = cmd(["stop_cluster"])
    {_, 0} = cmd(["create_network"])
    Enum.map(1..size, fn i -> create_node(i, size) end)
  end

  defp create_node(i, cluster_size) do
    {_, 0} = cmd(["create_node", "#{i} #{cluster_size}"])
    n = n(i)
    true = wait_for_node(n)
    n
  end

  def start_node(n) do
    {_, 0} = cmd(["start_node", "#{Node.id(n)}"])
    true = wait_for_node(n)
  end

  def stop_node(n) do
    {_, 0} = cmd(["stop_node", "#{Node.id(n)}"])
  end

  defp wait_for_node(n) do
    eventually(fn ->
      case HTTPoison.get("http://#{Node.host(n)}:#{Node.port(n)}/status", []) do
        {:ok, r} -> r.status_code == 200
        _ -> false
      end
    end)
  end

  def n(i) do
    Node.new(i, fn ->
      {ip, 0} = cmd(["node_ip", "#{i}"])
      String.trim(ip)
    end)
  end

  def session_ids(n) do
    r = HTTPoison.get!("http://#{Node.host(n)}:#{Node.port(n)}/sessions")
    Poison.decode!(r.body) |> Enum.sort
  end

  defp cmd(cmd) do
    path = Path.join([File.cwd!, "priv", "cluster.sh"])
    System.cmd(path, cmd, stderr_to_stdout: true)
  end

end
