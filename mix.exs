defmodule BreakingPp.MixProject do
  use Mix.Project

  def project do
    [
      app: :breaking_pp,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {BreakingPP.Application, []}
    ]
  end

  defp deps do
    [
      {:poison, "~> 3.1"},
      {:cowboy, "~> 2.4"},
      {:phoenix_pubsub, "~> 1.0"},
      {:httpoison, "~> 1.1", only: :test},
      {:socket, "~> 0.3.13", only: :test}
    ]
  end
end
