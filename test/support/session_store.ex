defmodule BreakingPP.Test.SessionStore do
  @table :sessions

  def new do
    try do
      :ets.delete(@table)
    rescue ArgumentError -> :ok
    end
    :ets.new(@table, [:named_table, :public, :set])
  end

  def store(ids, sessions) do
    Enum.zip(ids, sessions)
    |> Enum.map(fn {i, s} -> :ets.insert(@table, {i, s}) end)
  end

  def take(ids) do
    Enum.map(ids, fn id -> :ets.take(@table, id) end)
    |> Enum.concat
    |> Enum.map(fn {_, s} -> s end)
  end
end
