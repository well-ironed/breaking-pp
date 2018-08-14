defmodule BreakingPP.SessionsListHandler do
  @behaviour :cowboy_handler

  def init(req, state) do
    tracker = BreakingPP.Config.tracker_module()
    body = Poison.encode!(tracker.session_ids())
    req = :cowboy_req.reply(200, %{}, body, req)
    {:ok, req, state}
  end

end
