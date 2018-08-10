defmodule BreakingPP.Test.Eventually do
  require Logger

  def eventually(f, retries \\ 300, sleep \\ 100)
  def eventually(_, 0, _), do: false
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
