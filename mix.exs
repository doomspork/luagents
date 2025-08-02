defmodule Luagents.MixProject do
  use Mix.Project

  def project do
    [
      app: :luagents,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:lua, "~> 0.3.0"},
      {:anthropix, "~> 0.6"},
      {:ollama, "0.8.0"},

      # Dev & Test dependencies
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end
end
