defmodule BreakingPP.Eventually do
  require Logger

  def eventually(f, retries \\ 120, sleep \\ 1_000)
  def eventually(f, 0, _) do
    Logger.error("Retries exceeded while waiting for: #{inspect f}")
    false
  end
  def eventually(f, retries, sleep) do
    result = try do
      f.()
    rescue e ->
      Logger.error("While waiting for eventually: #{inspect e}")
      false
    end
    case result do
      false -> 
        Process.sleep(sleep)
        eventually(f, retries-1, sleep)
      nil ->
        Process.sleep(sleep)
        eventually(f, retries-1, sleep)
      other ->
        other
    end
  end

end
