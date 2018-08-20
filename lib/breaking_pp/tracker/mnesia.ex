defmodule BreakingPP.Tracker.Mnesia do
  @behaviour Phoenix.Tracker
  @table :presence_mnesia

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def handle_diff(_diff, state) do
    {:ok, state}
  end

  def session_ids do
    {:atomic, ids} = :mnesia.transaction(fn ->
      :mnesia.all_keys(@table)
    end)
    ids
  end

  def register(pid, id) do
    GenServer.call(__MODULE__, {:register, {id, pid}})
  end

  def sync_with(nodes) do
    GenServer.cast(__MODULE__, {:sync_with, nodes})
  end

  ## GenServer Callbacks

  def init(_opts) do
    :ok = :mnesia.start()
    :mnesia.change_config(:extra_db_nodes, Node.list())
    :mnesia.create_table(@table, attributes: [:id, :pid])
    :mnesia.add_table_copy(@table, Node.self(), :ram_copies)
    {:ok, %{monitored: []}}
  end

  def handle_call({:register, {id, _} = session}, _from, state) do
    IO.inspect(:mnesia.table_info(@table, :all), limit: 1000)
    ^id = register_session(session)
    {:reply, {:ok, id}, state}
  end

  def handle_cast({:sync_with, _nodes}, state) do
    # Enum.each(nodes, fn node->
    #   :mnesia.change_config(:extra_db_nodes, [node])
    #   :mnesia.add_table_copy(@table, node, :ram_copies)
    # end)
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:atomic, _} = :mnesia.transaction(fn ->
      [obj] = :mnesia.match_object(@table, {@table, :'_', pid}, :read)
      :ok = :mnesia.delete_object(obj)
    end)
    {:noreply, state}
  end

  defp register_session({id, pid}) do
    _ref = Process.monitor(pid)
    IO.inspect(:mnesia.table_info(@table, :all))
    {:atomic, _} = :mnesia.transaction(fn ->
      :ok = :mnesia.write({@table, id, pid})
    end)
    id
  end

end
