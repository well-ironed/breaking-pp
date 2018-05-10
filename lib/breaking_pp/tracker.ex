defmodule BreakingPP.Tracker do
  @behaviour Phoenix.Tracker
  @topic "breaking-pp"

  def start_link(opts) do
    GenServer.start_link(
      Phoenix.Tracker, [__MODULE__, opts, opts], name: __MODULE__)
  end

  def init(opts) do
    server = Keyword.fetch!(opts, :pubsub_server)
    {:ok, %{pubsub_server: server, node_name: Phoenix.PubSub.node_name(server)}}
  end

  def handle_diff(_diff, state) do
    {:ok, state}
  end

  def session_ids do
    Phoenix.Tracker.list(__MODULE__, @topic)
    |> Enum.map(fn {id, _} -> id end)
  end

  def register(pid, id) do
    Phoenix.Tracker.track(__MODULE__, pid, @topic, id, %{})
  end
end

