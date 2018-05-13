defmodule BreakingPP.Test.ClusterTest do
  use ExUnit.Case
  import BreakingPP.Test.Eventually

  test "active sessions are replicated in the cluster" do
    [n1, n2] = given_cluster(2)

    session_connected(n1, "1")
    session_connected(n2, "2")
  
    assert eventually(fn -> sessions(n2) == ["1", "2"] end)
    assert eventually(fn -> sessions(n1) == ["1", "2"] end)
  end

  test "closed sessions are replicated in the cluster" do
    [n1, n2] = given_cluster(2)

    s = session_connected(n1, "1")
    true = eventually(fn -> sessions(n2) == ["1"] end)
    session_disconnected(s)

    assert eventually(fn -> sessions(n2) == [] end)
  end

  defp given_cluster(size) do
    {_, 0} = cmd(["stop_cluster"])
    {_, 0} = cmd(["create_network"])
    Enum.map(1..size, fn i -> start_node(i, size) end)
  end

  defp session_connected(n, id) do
    Socket.Web.connect!(n.host, n.port, path: "/sessions/#{id}")
  end

  defp session_disconnected(socket) do
    :ok = Socket.Web.close(socket)
  end

  defp sessions(n) do
    r = HTTPoison.get!("http://#{n.host}:#{n.port}/sessions")
    Poison.decode!(r.body) |> Enum.sort
  end

  defp start_node(i, cluster_size) do
    {_, 0} = cmd(["start_node", "#{i} #{cluster_size}"])
    host = "localhost"
    port = i*10_000 + 4_000
    eventually(fn ->
      case HTTPoison.get("http://#{host}:#{port}/status", []) do
        {:ok, r} -> r.status_code == 200
        _ -> false
      end
    end)
    %{host: host, port: port}
  end

  defp cmd(cmd) do
    System.cmd(Path.join([File.cwd!, "priv", "cluster.sh"]), cmd)
  end
end
