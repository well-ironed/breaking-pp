defmodule BreakingPP.Test.Eventually do

  def eventually(f, retries \\ 300, sleep \\ 100)
  def eventually(_, 0, _), do: raise "retries exceeded"
  def eventually(f, retries, sleep) do
    case f.() do
      true ->
        true
      false -> 
        Process.sleep(sleep)
        eventually(f, retries-1, sleep)
    end
  end

end
