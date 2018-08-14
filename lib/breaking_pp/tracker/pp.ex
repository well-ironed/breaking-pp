defmodule BreakingPP.Tracker.PP do
  @behaviour Phoenix.Tracker
  @topic "breaking-pp"

  def start_link(opts) do
    Phoenix.Tracker.start_link(__MODULE__, opts, opts)
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

  def sync_with(_) do
    # This is unnecessary with the Phoenix Pubsub tracker
    :ok
  end

end

