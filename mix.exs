defmodule TMF882X.MixProject do
  use Mix.Project

  def project do
    [
      app: :tmf882x,
      version: "0.1.0",
      elixir: "~> 1.12",
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:circuits_i2c, "~> 1.0"},
      {:circuits_gpio, "~> 1.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev}
    ]
  end

  defp aliases do
    [
      validate: [
        "clean",
        "compile --warnings-as-error",
        "format --check-formatted",
        "credo",
        "dialyzer"
      ]
    ]
  end

  defp description do
    """
    Driver for the TMF882X family of multi-zone direct time-of-flight (dToF) distance sensor
    """
  end

  defp package do
    [
      files: ["lib/tmf882x.ex", "lib/tmf882x", "mix.exs", "README*"],
      maintainers: ["Powell Kinney"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/pkinney/tmf882x"}
    ]
  end
end
