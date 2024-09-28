defmodule Otelcol.MixProject do
  use Mix.Project

  @version "0.1.3"
  @source_url "https://github.com/kenichi/otelcol"

  def project do
    [
      app: :otelcol,
      version: @version,
      elixir: "~> 1.10",
      otp: ">= 22.0",
      deps: deps(),
      description: "Mix tasks for installing and invoking otelcol",
      package: [
        links: %{
          "GitHub" => @source_url,
          "otelcol" => "https://github.com/open-telemetry/opentelemetry-collector-contrib"
        },
        licenses: ["MIT"]
      ],
      docs: [
        main: "Otelcol",
        source_url: @source_url,
        source_ref: "v#{@version}",
        extras: ["CHANGELOG.md"]
      ],
      xref: [
        exclude: [:httpc, :public_key]
      ],
      aliases: [test: ["otelcol.install --if-missing", "test"]]
    ]
  end

  def application do
    extra =
      case Mix.env() do
        :test ->
          [:crypto, :inets, :logger, :public_key, :ssl]

        _ ->
          [:logger]
      end

    [
      extra_applications: extra,
      mod: {Otelcol, []},
      env: [default: []]
    ]
  end

  defp deps do
    [
      {:castore, ">= 0.0.0"},
      {:ex_doc, ">= 0.0.0", only: :docs}
    ]
  end
end
