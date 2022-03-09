defmodule OtelcolTest do
  use ExUnit.Case, async: true

  @version Otelcol.latest_version()
  @config_file "config/otel-collector.yml"

  setup do
    Application.put_env(:otelcol, :version, @version)
    File.mkdir_p!("config")
    File.rm(@config_file)
    :ok
  end

  test "run on default" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Otelcol.run(:default, ["--version"]) == 0
           end) =~ @version
  end

  test "run on profile" do
    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Otelcol.run(:another, []) == 0
           end) =~ @version
  end

  test "updates on install" do
    Application.put_env(:otelcol, :version, "0.45.0")
    Mix.Task.rerun("otelcol.install", ["--if-missing"])

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Otelcol.run(:default, ["--version"]) == 0
           end) =~ "0.45.0"

    Application.delete_env(:otelcol, :version)

    Mix.Task.rerun("otelcol.install", ["--if-missing"])
    assert File.exists?(@config_file)

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert Otelcol.run(:default, ["--version"]) == 0
           end) =~ @version
  end
end
