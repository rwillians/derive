defmodule Derive.MixProject do
  use Mix.Project

  @version "0.4.3"
  @github "https://github.com/rwillians/derive"

  @description """
  A small, simple, and yet flexible API for deriving state from an event source, that works out of the box with Ecto.
  """

  def project do
    [
      app: :derive,
      version: @version,
      description: @description,
      source_url: @github,
      homepage_url: @github,
      elixir: ">= 1.17.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [debug_info: Mix.env() == :dev],
      build_embedded: Mix.env() not in [:dev, :test],
      aliases: aliases(),
      package: package(),
      docs: [
        main: "README",
        source_ref: "v#{@version}",
        source_url: @github,
        canonical: "http://hexdocs.pm/derive/",
        extras: ["LICENSE"]
      ],
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix],
        plt_add_deps: :apps_direct,
        flags: [:unmatched_returns, :error_handling, :underspecs],
        plt_core_path: "priv/plts/core",
        plt_local_path: "priv/plts/local"
      ],
      test_coverage: [
        summary: [threshold: 80]
      ]
    ]
  end

  defp package do
    [
      files: ~w(lib mix.exs .formatter.exs README.md LICENSE),
      maintainers: ["Rafael Willians"],
      contributors: ["Rafael Willians"],
      licenses: ["MIT"],
      links: %{
        GitHub: @github,
        Changelog: "#{@github}/releases"
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "ecto.dump"],
      "ecto.reset": ["ecto.drop --quiet", "ecto.setup"]
    ]
  end

  def cli do
    [
      #
    ]
  end

  defp deps do
    [
      # ↓ dev dependencies
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.39", only: [:dev, :docs], runtime: false},
      # ↓ runtime dependencies
      {:ecto_sql, "~> 3.13"},
      {:jason, "~> 1.4"},
      {:postgrex, ">= 0.0.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
