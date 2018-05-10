defmodule BreakingPP.SessionsListHandler do
  @behaviour :cowboy_handler

  def init(req, state) do
    body = Poison.encode!(BreakingPP.Tracker.session_ids())
    req = :cowboy_req.reply(200, %{}, body, req)
    {:ok, req, state}
  end

end
