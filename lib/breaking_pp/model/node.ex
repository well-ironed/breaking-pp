defmodule BreakingPP.Model.Node do
  defstruct [:id, :host, :port]

  def new(id, host) when is_function(host, 0) do
    %__MODULE__{id: id, host: host, port: 4000}
  end

  def id(%__MODULE__{id: id}), do: id

  def host(%__MODULE__{host: host}), do: host.()

  def port(%__MODULE__{port: port}), do: port

end
