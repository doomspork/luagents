defmodule Luagents.MixProject do
  use Mix.Project

  @source_url "https://github.com/doomspork/luagents"
  @version "0.3.0"

  def project do
    [
      app: :luagents,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:anthropix, "~> 0.6"},
      {:lua, "~> 0.3.0"},
      {:ollama, "0.9.0"},
      {:req, "~> 0.5", optional: true},
      {:jason, "~> 1.4", optional: true},

      # Dev & Test dependencies
      {:bypass, "~> 2.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md",
        "LICENSE.md",
        "README.md"
      ],
      formatters: ["html"],
      homepage_url: @source_url,
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp package do
    [
      name: "luagents",
      description: "Luagents is a library for building agents that can use Lua code to reason and act.",
      files: [
        "lib",
        "mix.exs",
        "README.md",
        "LICENSE.md",
        "CHANGELOG.md",
        ".formatter.exs"
      ],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "https://hexdocs.pm/luagents/changelog.html",
        "GitHub" => @source_url
      },
      maintainers: [
        "doomspork (iamdoomspork@gmail.com)"
      ]
    ]
  end
end
