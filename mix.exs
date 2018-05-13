defmodule BreakingPp.MixProject do
  use Mix.Project

  def project do
    [
      app: :breaking_pp,
      version: "0.1.0",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env),
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:cowboy, "~> 2.4"},
      {:poison, "~> 3.1"},
      {:phoenix_pubsub, "~> 1.0"},
      {:distillery, "~> 1.5", runtime: false},
      {:httpoison, "~> 1.1", only: :test},
      {:socket, "~> 0.3.13", only: :test}
    ]
  end
end
