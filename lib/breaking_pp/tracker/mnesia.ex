defmodule BreakingPP.Tracker.Mnesia do
  @behaviour Phoenix.Tracker
  @table :presence_mnesia
  @server __MODULE__

  def start_link(opts), do: GenServer.start_link(@server, opts, name: @server)

  def handle_diff(_diff, st), do: {:ok, st}

  def session_ids, do: GenServer.call(@server, :get_session_ids)

  def register(pid, id), do: GenServer.call(@server, {:register, {id, pid}})

  def sync_with(nodes), do: GenServer.call(@server, {:sync_with, nodes})

  ## GenServer Callbacks

  def init(_opts) do
    :mnesia.start()
    :net_kernel.monitor_nodes(true)
    {:ok, %{monitored: [], synced: false}}
  end

  def handle_call(:get_session_ids, _from, %{synced: false}=st) do
    {:reply, [], st}
  end
  def handle_call(:get_session_ids, _from, %{synced: true}=st) do
    ids = (:mnesia.dirty_select(@table, [{:'_', [], [:'$_']}])
      |> Enum.map(&elem(&1,1)))
    {:reply, ids, st}
  end

  def handle_call({:register, {id, _} = session}, _from, %{synced: true}=st) do
    ^id = register_session(session)
    {:reply, {:ok, id}, st}
  end

  def handle_call({:sync_with, nodes}, _, %{synced: true} = st) do
    {:reply, :ok, st}
  end

  def handle_call({:sync_with, []}, _, %{synced: false} = st) do
    :mnesia.create_table(@table, attributes: [:id, :pid], ram_copies: node())
    {:reply, :ok, %{st | synced: true}}
  end

  def handle_call({:sync_with, nodes}, _, %{synced: false} = st) do
    :global.trans(lock_id(), fn ->
      active = MapSet.new(:mnesia.system_info(:running_db_nodes))
      syncing = MapSet.new(nodes)
      case active == syncing do
        false ->
          :mnesia.change_config(:extra_db_nodes, (nodes--[node()]))
          :mnesia.create_table(@table, attributes: [:id, :pid, :node],
            ram_copies: nodes)
        true ->
          :ok
      end
    end, nodes, 100)
    {:reply, :ok,  %{st | synced: true}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, st) do
    :mnesia.dirty_match_object(@table, {@table, :'_', pid, :'_'})
    |> Enum.each(&:mnesia.dirty_delete_object(&1))
    {:noreply, st}
  end

  def handle_info({:nodedown, node}, st) do
    :mnesia.dirty_match_object({@table, :'_', :'_', node})
    |> Enum.each(&:mnesia.dirty_delete_object(&1))
    {:noreply, st}
  end

  def handle_info({:nodeup, node}, st) do
    :ok = send_my_state_to(node)
    {:noreply, st}
  end

  def handle_info({:remote_entries, entries}, st) do
    Enum.each(entries,
      fn({_, id, pid, _}) -> register_session({id, pid}) end)
    {:noreply, st}
  end

  defp register_session({id, pid}) do
    _ref = Process.monitor(pid)
    :ok = :mnesia.dirty_write({@table, id, pid, node(pid)})
    id
  end

  defp lock_id(), do: {@server, self()}

  defp send_my_state_to(other_node) do
    try do
      this_node = node()
      entries = :mnesia.dirty_match_object({@table, :'_', :'_', this_node})
      _ = send({@server, other_node}, {:remote_entries, entries})
      :ok
    catch _, _  ->
        :ok
    end
  end

end
