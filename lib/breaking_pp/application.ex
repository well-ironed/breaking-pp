defmodule BreakingPP.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec

  def start(_type, _args) do
    start_endpoints()

    children = [
      supervisor(Phoenix.PubSub.PG2, [BreakingPP.PubSub, []]),
      worker(BreakingPP.Tracker,
        [[name: BreakingPP.Tracker, pubsub_server: BreakingPP.PubSub]])
    ]

    opts = [strategy: :one_for_one, name: BreakingPP.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp start_endpoints do
    dispatch = :cowboy_router.compile([
      {:"_", [
          {"/sessions/:id", BreakingPP.SessionsHandler, []},
          {"/sessions", BreakingPP.SessionsListHandler, []}]}
    ])

    {:ok, _} = :cowboy.start_clear(
      __MODULE__, [{:port, 4000}], %{env: %{dispatch: dispatch}})
  end

end
