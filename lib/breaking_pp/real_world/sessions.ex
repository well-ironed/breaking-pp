defmodule BreakingPP.RealWorld.Sessions do
  alias BreakingPP.RealWorld.Session
  defstruct [:sessions]
  @table :sessions

  def new do
    try do
      :ets.delete(@table)
    rescue ArgumentError -> :ok
    end
    :ets.new(@table, [:named_table, :public, :set])
  end

  def connect(node, ids) do
    Enum.map(ids, fn id ->
      s = Session.new(node, id)
      :ets.insert(@table, {id, s})
    end)
  end

  def disconnect(ids) do
    Enum.map(ids, fn id -> :ets.take(@table, id) end)
    |> Enum.concat
    |> Enum.map(fn {_, s} -> Session.close(s) end)
  end
end
