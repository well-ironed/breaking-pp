defmodule BreakingPP.RealWorld.Node do
  defstruct [:id, :host, :port]

  @type id :: integer
  @type t :: %__MODULE__{
    id: id,
    host: String.t,
    port: integer}

  def new(id, host) do
    %__MODULE__{id: id, host: host, port: 4000}
  end

  def id(%__MODULE__{id: id}), do: id

  def host(%__MODULE__{host: host}), do: host

  def port(%__MODULE__{port: port}), do: port

end
