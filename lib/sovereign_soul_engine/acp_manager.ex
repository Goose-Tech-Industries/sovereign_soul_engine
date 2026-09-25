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

  def start do
    port = configured_port()
    log_path = configured_log_path()

    if not running?(port) do
      Logger.info("Starting ACP server on port #{port}...")
      File.mkdir_p!(Path.dirname(log_path))

      # Start in background using a Task running System.cmd
      Task.start(fn ->
        System.cmd(
          "opencode",
          ["acp", "--hostname", "0.0.0.0", "--port", to_string(port), "--print-logs"],
          into: File.stream!(log_path, [:write, :utf8]),
          cd: "/root"
        )
      end)

      # Wait a short moment to allow startup
      :timer.sleep(1000)
      running?(port)
    else
      true
    end
  end

  def stop do
    Logger.info("Stopping ACP server...")
    System.cmd("pkill", ["-f", "opencode acp"])
    :timer.sleep(500)
    not running?(configured_port())
  end

  def restart do
    stop()
    start()
  end

  def get_logs(lines \\ 30) do
    log_path = configured_log_path()

    if File.exists?(log_path) do
      log_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.take(-lines)
      |> Enum.join("\n")
    else
      "No logs found at #{log_path}."
    end
  end

  defp configured_port do
    Application.get_env(:sovereign_soul_engine, :acp_port, @default_port)
  end

  defp configured_log_path do
    Application.get_env(:sovereign_soul_engine, :acp_log_path, @default_log_path)
  end
end
