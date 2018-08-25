alias BreakingPP.Model

[file] = System.argv
{:ok, [cmds]} = :file.consult(file)

just_fas = fn {:set, _, {:call, _, f, a}} -> {f, a} end

node = fn n -> "n#{Model.Node.id(n)}" end
nodes = fn n -> Enum.map(1..n, &("n#{&1}")) |> Enum.join(", ") end

eventually = fn c ->
  started_nodes = Model.Cluster.started_nodes(c)
  started_nodes_vars = Enum.map(started_nodes, node) |> Enum.join(", ")
  ids_on_started_nodes =
    Enum.map(started_nodes, fn n -> Model.Cluster.sessions(c, n) end)
    |> Enum.map(fn sessions -> Enum.map(sessions, &Model.Session.id/1) end)
    |> Enum.map(fn ids -> Enum.sort(ids) end)
    """
    assert eventually(fn -> 
      Cluster.session_ids_on_nodes([#{started_nodes_vars}]) ==
        #{inspect ids_on_started_nodes, limit: :infinity}
    end)
    """
end

fa_to_test = fn 
  {:start_cluster, [size]}, _ ->
    c = Enum.reduce(1..size, Model.Cluster.new, fn n, c ->
      Model.Cluster.start_node(c, Model.Node.new(n))
    end)
    {["[#{nodes.(size)}] = Cluster.start(#{size})"], c}

  {:stop_node, [n]}, c ->
    c = Model.Cluster.stop_node(c, n)
    stop = "Cluster.stop_node(#{node.(n)})"
    {[stop, eventually.(c)], c}

  {:start_node, [n]}, c ->
    c = Model.Cluster.start_node(c, n)
    start = "Cluster.start_node(#{node.(n)})"
    {[start, eventually.(c)], c}

  {:split, [n1, n2]}, c ->
    c = Model.Cluster.split(c, n1, n2)
    {["Cluster.split(#{node.(n1)}, #{node.(n2)})", eventually.(c)], c}

  {:join, [n1, n2]}, c ->
    c = Model.Cluster.join(c, n1, n2)
    {["Cluster.join(#{node.(n1)}, #{node.(n2)})", eventually.(c)], c}

  {:connect_sessions, [sessions]}, c ->
    c = Model.Cluster.add_sessions(c, sessions)
    connects = Enum.group_by(sessions, &Model.Session.node/1)
    |> Enum.map(fn {n, ss} ->
      session_ids = Enum.map(ss, &Model.Session.id/1)
      "Cluster.connect(#{node.(n)}, #{inspect session_ids, limit: :infinity})"
    end)
    {connects ++ [eventually.(c)], c}

  {:disconnect_sessions, [sessions]}, c ->
    c = Model.Cluster.remove_sessions(c, sessions)
    disconnects = Enum.group_by(sessions, &Model.Session.node/1)
    |> Enum.map(fn {n, ss} ->
      session_ids = Enum.map(ss, &Model.Session.id/1)
      "Cluster.disconnect(#{inspect session_ids, limit: :infinity}) ##{node.(n)}"
    end)
    {disconnects ++ [eventually.(c)], c}
    
end
    
Enum.map(cmds, just_fas)
|> Enum.map_reduce(nil, fa_to_test)
|> elem(0)
|> Enum.map(&Enum.join(&1, "\n"))
|> Enum.map(&([&1, "\n"]))
|> Enum.each(&IO.puts/1)
