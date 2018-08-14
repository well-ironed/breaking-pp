defmodule BreakingPP.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec

  def start(_type, _args) do
    start_endpoints()
    {tracker_module, tracker_opts} = BreakingPP.Config.tracker_mod_opts()
    children = [
      supervisor(Phoenix.PubSub.PG2, [BreakingPP.PubSub, []]),
      worker(tracker_module, [tracker_opts]),
      worker(BreakingPP.Cluster, [])
    ]

    opts = [strategy: :one_for_one, name: BreakingPP.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp start_endpoints do
    dispatch = :cowboy_router.compile([
      {:"_", [
          {"/status", BreakingPP.StatusHandler, []},
          {"/sessions/:id", BreakingPP.SessionsHandler, []},
          {"/sessions", BreakingPP.SessionsListHandler, []}]}
    ])

    {:ok, _} = :cowboy.start_clear(
      __MODULE__, [{:port, 4000}], %{env: %{dispatch: dispatch}})
  end

end
