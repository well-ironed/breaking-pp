defmodule BreakingPP.Tracker do
  @behaviour Phoenix.Tracker
  @table :breaking_pp

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def handle_diff(_diff, state) do
    {:ok, state}
  end

  def session_ids do
    :ets.tab2list(@table)
    |> Enum.map(fn {id, _pid} -> id end)
  end

  def register(pid, id) do
    GenServer.call(__MODULE__, {:register, {id, pid}})
  end

  def sync_with(nodes) do
    GenServer.cast(__MODULE__, {:sync_with, nodes})
  end

  def local_state(), do: :ets.tab2list(@table)

  ## GenServer Callbacks

  def init(_opts) do
    @table = :ets.new(@table, [:named_table, :public])
    {:ok, %{monitored: []}}
  end

  def handle_call({:register, {id, _} = session}, _from, state) do
    ^id = register_session(session)
    {:reply, {:ok, id}, state}
  end

  def handle_cast({:sync_with, nodes}, state) do
    :rpc.sbcast(nodes -- [Node.self()], __MODULE__, {:sync_with_me, self()})
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    _ = :ets.match_delete(@table, {:"$1", pid})
    {:noreply, state}
  end

  def handle_info({:sync_with_me, origin}, state) do
    send(origin, {:sync_payload, local_state()})
    {:noreply, state}
  end

  def handle_info({:sync_payload, remote_state}, state) do
    Enum.each(remote_state, &register_session/1)
    {:noreply, state}
  end

  defp register_session({id, pid}) do
    _ref = Process.monitor(pid)
    true = :ets.insert(@table, {id, pid})
    id
  end

end
