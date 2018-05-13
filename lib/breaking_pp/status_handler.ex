defmodule BreakingPP.StatusHandler do
  @behaviour :cowboy_handler

  def init(req, state) do
    req = :cowboy_req.reply(200, req)
    {:ok, req, state}
  end

end
