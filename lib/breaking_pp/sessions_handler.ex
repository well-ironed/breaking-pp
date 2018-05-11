defmodule BreakingPP.SessionsHandler do
  @behaviour :cowboy_websocket

  def init(req, _) do
    id = :cowboy_req.binding(:id, req)
    {:cowboy_websocket, req, %{id: id}, %{idle_timeout: :infinity}}
  end

  def websocket_init(%{id: id}=state) do
    {:ok, _} = BreakingPP.Tracker.register(self(), id)
    {:ok, state}
  end

  def websocket_handle(_, state) do
    {:ok, state}
  end

  def websocket_info(_, state) do
    {:ok, state}
  end

  def terminate(_, _, _), do: :ok
end
