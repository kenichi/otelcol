# Otelcol (OpenTelemetry Collector)

[![CI](https://github.com/kenichi/otelcol/actions/workflows/main.yml/badge.svg)](https://github.com/kenichi/otelcol/actions/workflows/main.yml)

Mix tasks for installing and invoking [otelcol-contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib).
Copied from [tailwind](https://github.com/phoenixframework/tailwind), with the
intent of easily running an OpenTelemetry Collector next to the server, in
development. It uses the contrib version to have as many options for export as
possible.

## Installation

Otelcol is intended as a development-only tool. Make sure to specify `only:
:dev` in your mix.exs:

```elixir
def deps do
  [
    {:otelcol, "~> 0.1", only: :dev}
  ]
end
```

Once installed, change your `config/config.exs` to pick your
otelcol version of choice:

```elixir
config :otelcol, version: "0.45.0"
```

Now you can install `otelcol-contrib` by running:

```bash
$ mix otelcol.install
```

And invoke otelcol with:

```bash
$ mix otelcol default
```

The executable is kept at `_build/otelcol-contrib`.

## Profiles

The first argument to `otelcol` is the execution profile.
You can define multiple execution profiles with the current
directory, the OS environment, and default arguments to the
`otelcol` task:

```elixir
config :otelcol,
  version: "0.46.0",
  default: [
    args: ~w(
      --config=config/otelcol-collector.yml
    )
  ]
```

When `mix otelcol default` is invoked, the task arguments will be appended
to the ones configured above. Note profiles must be configured in your
`config/config.exs`, as `otelcol` runs without starting your application
(and therefore it won't pick settings in `config/runtime.exs`).

## Adding to Phoenix

To add `otelcol` to an application using Phoenix, you need one more step.
Installation requires that Phoenix watchers can accept module-function-args
tuples which is not built into Phoenix 1.5.9.

For development, we want to use "watch" mode, even though we're not really
watching any files. So find the `watchers` configuration in your
`config/dev.exs` and add:

```elixir
  otelcol: {Otelcol, :install_and_run, [:default, []]}
```

## Otelcol Configuration

The first time this package is installed, a default otelcol configuration
will be placed in a new `config/otel-collector.yml` file. See
the [otelcol documentation](https://github.com/open-telemetry/opentelemetry-collector-contrib)
on configuration options.

## License

Copyright (c) 2022 Kenichi Nakamura.
copied/modded from https://github.com/phoenixframework/tailwind
Copyright (c) 2021 Wojtek Mach, José Valim.

otelcol source code is licensed under the [MIT License](LICENSE.md).
