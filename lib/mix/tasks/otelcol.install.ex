defmodule Mix.Tasks.Otelcol.Install do
  @moduledoc """
  Installs otelcol under `_build`.

  ```bash
  $ mix otelcol.install
  $ mix otelcol.install --if-missing
  ```

  By default, it installs #{Otelcol.latest_version()} but you
  can configure it in your config files, such as:

      config :otelcol, :version, "#{Otelcol.latest_version()}"

  ## Options

      * `--runtime-config` - load the runtime configuration
        before executing command

      * `--if-missing` - install only if the given version
        does not exist
  """

  @shortdoc "Installs otelcol under _build"
  use Mix.Task

  @impl true
  def run(args) do
    valid_options = [runtime_config: :boolean, if_missing: :boolean]

    case OptionParser.parse_head!(args, strict: valid_options) do
      {opts, []} ->
        if opts[:if_missing] && latest_version?() do
          :ok
        else
          Otelcol.install()
        end

      {_, _} ->
        Mix.raise("""
        Invalid arguments to otelcol.install, expected one of:

            mix otelcol.install
            mix otelcol.install --if-missing
        """)
    end
  end

  defp latest_version?() do
    version = Otelcol.configured_version()
    match?({:ok, ^version}, Otelcol.bin_version())
  end
end
