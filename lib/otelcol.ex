defmodule Otelcol do
  # https://github.com/open-telemetry/opentelemetry-collector-releases/releases
  @latest_version "0.58.0"

  @moduledoc """
  Otelcol is an installer and runner for
  [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector-contrib).

  ## Profiles

  You can define multiple otelcol profiles. By default, there is a
  profile called `:default` which you can configure its args, current
  directory and environment:

      config :otelcol,
        version: "#{@latest_version}",
        default: [
          args: ~w(
            --config=config/otel-collector.yml
          )
        ]

  ## Otelcol configuration

  There is one global configuration for the otelcol application:

    * `:version` - the expected `otecol-contrib` version

  ## Installation

  The first time this package is installed, two things will happen:

    * a default otelcol configuration will be placed in a new
      `config/otel-collector.yml` file, if it doesn't already exist. See the
      [otel-collector documentation](https://opentelemetry.io/docs/collector/configuration/)
      on configuration options.

    * a "zombie process"
      [wrapper script](https://hexdocs.pm/elixir/Port.html#module-zombie-operating-system-processes)
      will be written along-side the `otelcol-contrib` binary. This wrapper
      requires bash and is needed to shut down otelcol properly when the local
      server exits. This is *not* meant for production use.
  """

  use Application
  require Logger

  @doc false
  def start(_, _) do
    unless Application.get_env(:otelcol, :version) do
      Logger.warn("""
      otelcol version is not configured. Please set it in your config files:

          config :otelcol, :version, "#{latest_version()}"
      """)
    end

    configured_version = configured_version()

    case bin_version() do
      {:ok, ^configured_version} ->
        :ok

      {:ok, version} ->
        Logger.warn("""
        Outdated otelcol version. Expected #{configured_version}, got #{version}. \
        Please run `mix otelcol.install` or update the version in your config files.\
        """)

      :error ->
        :ok
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end

  @doc false
  # Latest known version at the time of publishing.
  def latest_version, do: @latest_version

  @doc """
  Returns the configured otelcol version.
  """
  def configured_version do
    Application.get_env(:otelcol, :version, latest_version())
  end

  @doc """
  Returns the configuration for the given profile.

  Returns nil if the profile does not exist.
  """
  def config_for!(profile) when is_atom(profile) do
    Application.get_env(:otelcol, profile) ||
      raise ArgumentError, """
      unknown otelcol profile. Make sure the profile is defined in your config/config.exs file, such as:

          config :otelcol,
            version: "#{latest_version()}",
            #{profile}: [
              args: ~w(
                --config=config/otel-collector-config.yml
              )
            ]
      """
  end

  @doc """
  Returns the path to the executable.

  The executable may not be available if it was not yet installed.
  """
  def bin_path do
    name = "otelcol-contrib"

    Application.get_env(:otelcol, :path) ||
      if Code.ensure_loaded?(Mix.Project) do
        Path.join(Path.dirname(Mix.Project.build_path()), name)
      else
        Path.expand("_build/#{name}")
      end
  end

  @doc """
  Returns the version of the otelcol executable.

  Returns `{:ok, version_string}` on success or `:error` when the executable
  is not available.
  """
  def bin_version do
    path = bin_path()

    with true <- File.exists?(path),
         {out, 0} <- System.cmd(path, ["--version"], stderr_to_stdout: true),
         [vsn] <- Regex.run(~r/otelcol-contrib version ([^\s]+)/, out, capture: :all_but_first) do
      {:ok, vsn}
    else
      _ -> :error
    end
  end

  @doc """
  Runs the given command with `args`.

  The given args will be appended to the configured args.
  The task output will be streamed directly to stdio. It
  returns the status of the underlying call.
  """
  def run(profile, extra_args) when is_atom(profile) and is_list(extra_args) do
    config = config_for!(profile)
    args = [bin_path() | config[:args] || []]

    opts = [
      cd: config[:cd] || File.cwd!(),
      env: config[:env] || %{},
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    ]

    zombie_wrapper_path()
    |> System.cmd(args ++ extra_args, opts)
    |> elem(1)
  end

  @doc """
  Installs, if not available, and then runs `otelcol`.

  Returns the same as `run/2`.
  """
  def install_and_run(profile, args) do
    unless File.exists?(bin_path()) do
      install()
    end

    run(profile, args)
  end

  @doc """
  Installs otelcol with `configured_version/0`.
  """
  def install do
    download_and_extract_release()
    write_otelcol_config()
    write_zombie_wrapper()
  end

  defp download_and_extract_release do
    version = configured_version()
    name = "otelcol-contrib_#{version}_#{target()}.tar.gz"

    url =
      "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v#{version}/#{name}"

    bin_path = bin_path()
    tgz = fetch_body!(url)

    {:ok, [{'otelcol-contrib', binary}]} =
      :erl_tar.extract({:binary, tgz}, [:memory, :compressed, files: ['otelcol-contrib']])

    File.mkdir_p!(Path.dirname(bin_path))
    remove_if_macos(bin_path)
    File.write!(bin_path, binary, [:binary])
    File.chmod(bin_path, 0o755)
  end

  # macOS includes "protections" where if a file is overwritten without being
  # removed first, it is considered tampered, and prevented from executing.
  defp remove_if_macos(bin_path),
    do: if(:os.type() == {:unix, :darwin}, do: :ok = File.rm(bin_path))

  defp write_otelcol_config do
    otelcol_config_path = Path.expand("config/otel-collector.yml")

    unless File.exists?(otelcol_config_path) do
      File.write!(otelcol_config_path, """
      receivers:
        otlp:
          protocols:
            grpc:

      exporters:
        logging:

      processors:
        batch:

      extensions:
        health_check:

      service:
        extensions: [health_check]
        pipelines:
          traces:
            receivers: [otlp]
            processors: [batch]
            exporters: [logging]
          metrics:
            receivers: [otlp]
            processors: [batch]
            exporters: [logging]
      """)
    end
  end

  defp write_zombie_wrapper do
    path = zombie_wrapper_path()

    unless File.exists?(path) do
      File.write!(path, zombie_wrapper())
      File.chmod!(path, 0o755)
    end
  end

  # Available targets:
  #
  #   * linux_amd64
  #   * linux_arm64
  #   * darwin_amd64
  #   * darwin_arm64
  #
  def target do
    arch_str = :erlang.system_info(:system_architecture)
    [arch | _] = arch_str |> List.to_string() |> String.split("-")

    case {:os.type(), arch, :erlang.system_info(:wordsize) * 8} do
      {{:unix, :darwin}, arch, 64} when arch in ~w(arm aarch64) -> "darwin_arm64"
      {{:unix, :darwin}, "x86_64", 64} -> "darwin_amd64"
      {{:unix, :linux}, "aarch64", 64} -> "linux_arm64"
      {{:unix, _osname}, arch, 64} when arch in ~w(x86_64 amd64) -> "linux_amd64"
      {_os, _arch, _wordsize} -> raise "otelcol is not available for architecture: #{arch_str}"
    end
  end

  def fetch_body!(url) do
    url = String.to_charlist(url)
    Logger.debug("Downloading otelcol from #{url}")

    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)

    if proxy = System.get_env("HTTP_PROXY") || System.get_env("http_proxy") do
      Logger.debug("Using HTTP_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)
      :httpc.set_options([{:proxy, {{String.to_charlist(host), port}, []}}])
    end

    if proxy = System.get_env("HTTPS_PROXY") || System.get_env("https_proxy") do
      Logger.debug("Using HTTPS_PROXY: #{proxy}")
      %{host: host, port: port} = URI.parse(proxy)
      :httpc.set_options([{:https_proxy, {{String.to_charlist(host), port}, []}}])
    end

    # https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/inets
    cacertfile = CAStore.file_path() |> String.to_charlist()

    http_options = [
      ssl: [
        verify: :verify_peer,
        cacertfile: cacertfile,
        depth: 2,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]

    options = [body_format: :binary]

    case :httpc.request(:get, {url, []}, http_options, options) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        body

      other ->
        raise "couldn't fetch #{url}: #{inspect(other)}"
    end
  end

  defp zombie_wrapper do
    """
    #!/usr/bin/env bash
    #
    # see [Port documentation](https://hexdocs.pm/elixir/Port.html#module-zombie-operating-system-processes)

    # Start the program in the background, filtering proto warnings
    exec "$@" 2> >(grep -v "duplicate proto type registered") &
    pid1=$!

    # Silence warnings from here on
    exec >/dev/null 2>&1

    # Read from stdin in the background and
    # kill running program when stdin closes
    exec 0<&0 $(
      while read; do :; done
      kill -KILL $pid1
    ) &
    pid2=$!

    # Clean up
    wait $pid1
    ret=$?
    kill -KILL $pid2
    exit $ret
    """
  end

  defp zombie_wrapper_path, do: Path.expand("_build/otelcol_wrapper")
end
