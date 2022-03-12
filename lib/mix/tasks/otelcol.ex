defmodule Mix.Tasks.Otelcol do
  @moduledoc """
  Invokes otelcol with the given args.

  Usage:

      $ mix otelcol TASK_OPTIONS PROFILE OTELCOL_ARGS

  Example:

      $ mix otelcol default --config=config/otel-collector-config.yml

  If otelcol is not installed, it is automatically downloaded.
  Note the arguments given to this task will be appended
  to any configured arguments.

  ## Options

    * `--runtime-config` - load the runtime configuration
      before executing command

  Note flags to control this Mix task must be given before the
  profile:

      $ mix otelcol --runtime-config default
  """

  @shortdoc "Invokes otelcol with the profile and args"

  use Mix.Task

  @impl true
  def run(args) do
    switches = [runtime_config: :boolean]
    {opts, remaining_args} = OptionParser.parse_head!(args, switches: switches)

    if opts[:runtime_config] do
      Mix.Task.run("app.config")
    else
      Application.ensure_all_started(:otelcol)
    end

    Mix.Task.reenable("otelcol")
    install_and_run(remaining_args)
  end

  defp install_and_run([profile | args] = all) do
    case Otelcol.install_and_run(String.to_atom(profile), args) do
      0 -> :ok
      status -> Mix.raise("`mix otelcol #{Enum.join(all, " ")}` exited with #{status}")
    end
  end

  defp install_and_run([]) do
    Mix.raise("`mix otelcol` expects the profile as argument")
  end
end
