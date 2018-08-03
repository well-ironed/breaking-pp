defmodule BreakingPp.MixProject do
  use Mix.Project

  def project do
    [
      app: :breaking_pp,
      version: "0.1.0",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
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

  defp aliases, do: [test: "test --exclude=property"]

  defp deps do
    [
      {:cowboy, "~> 2.4"},
      {:poison, "~> 3.1"},
      {:phoenix_pubsub,
        git: "https://github.com/phoenixframework/phoenix_pubsub.git",
        branch: "master"},
      {:recon, "~> 2.3"},
      {:distillery, "~> 1.5", runtime: false},
      {:httpoison, "~> 1.1", only: :test},
      {:propcheck, "~> 1.0", only: :test},
      {:socket, "~> 0.3.13", only: :test}
    ]
  end
end
