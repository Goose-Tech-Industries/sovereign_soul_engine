defmodule SovereignSoulEngine.AcpManager do
  require Logger
  @default_port 4005
  @default_log_path "/root/.config/opencode/acp.log"

  def running?(port \\ configured_port()) do
    case :gen_tcp.connect(~c"127.0.0.1", port, [:binary, active: false], 200) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true

      _ ->
        false
    end
  end

  # Optional adapters keep lifecycle tests isolated from host processes.
  def start(opts \\ []) do
    probe = Keyword.get(opts, :probe, &running?/0)

    if probe.() do
      true
    else
      launch = Keyword.get(opts, :launch, &launch/0)
      wait = Keyword.get(opts, :wait, &:timer.sleep/1)

      case launch.() do
        {:ok, _} ->
          wait.(1000)
          probe.()

        {:error, _} ->
          false
      end
    end
  rescue
    error in [File.Error, ErlangError] ->
      Logger.warning("ACP startup failed: #{Exception.message(error)}")
      false
  end

  def stop(opts \\ []) do
    command = Keyword.get(opts, :command, &System.cmd/2)
    wait = Keyword.get(opts, :wait, &:timer.sleep/1)
    probe = Keyword.get(opts, :probe, &running?/0)

    case command.("pkill", ["-f", "opencode acp"]) do
      {_, status} when status in [0, 1] ->
        wait.(500)
        not probe.()

      _ ->
        false
    end
  rescue
    error in ErlangError ->
      Logger.warning("ACP shutdown failed: #{Exception.message(error)}")
      false
  end

  def restart(opts \\ []) do
    if stop(opts), do: start(opts), else: false
  end

  def get_logs(lines \\ 30) when is_integer(lines) and lines >= 0 do
    path = configured_log_path()

    case File.read(path) do
      {:ok, content} ->
        content
        |> String.trim_trailing("\n")
        |> String.split("\n")
        |> Enum.take(-lines)
        |> Enum.join("\n")

      {:error, :enoent} ->
        "No logs found at #{path}."

      {:error, reason} ->
        "Unable to read logs: #{:file.format_error(reason)}"
    end
  end

  defp launch do
    path = configured_log_path()
    port = configured_port()
    File.mkdir_p!(Path.dirname(path))

    Task.start(fn ->
      try do
        System.cmd(
          "opencode",
          ["acp", "--hostname", "0.0.0.0", "--port", to_string(port), "--print-logs"],
          into: File.stream!(path, [:write, :utf8]),
          cd: "/root"
        )
      rescue
        error -> Logger.warning("ACP process failed: #{Exception.message(error)}")
      end
    end)
  end

  defp configured_port, do: Application.get_env(:sovereign_soul_engine, :acp_port, @default_port)

  defp configured_log_path,
    do: Application.get_env(:sovereign_soul_engine, :acp_log_path, @default_log_path)
end
