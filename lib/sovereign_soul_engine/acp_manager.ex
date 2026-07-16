defmodule SovereignSoulEngine.AcpManager do
  require Logger

  @port 4005
  @log_path "/root/.config/opencode/acp.log"

  def running? do
    case :gen_tcp.connect(~c"127.0.0.1", @port, [:binary, active: false], 200) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true
      _ ->
        false
    end
  end

  def start do
    if not running?() do
      Logger.info("Starting ACP server on port #{@port}...")
      File.mkdir_p!(Path.dirname(@log_path))

      # Start in background using a Task running System.cmd
      Task.start(fn ->
        System.cmd("opencode", ["acp", "--hostname", "0.0.0.0", "--port", to_string(@port), "--print-logs"],
          into: File.stream!(@log_path, [:write, :utf8]),
          cd: "/root"
        )
      end)
      # Wait a short moment to allow startup
      :timer.sleep(1000)
      running?()
    else
      true
    end
  end

  def stop do
    Logger.info("Stopping ACP server...")
    System.cmd("pkill", ["-f", "opencode acp"])
    :timer.sleep(500)
    not running?()
  end

  def restart do
    stop()
    start()
  end

  def get_logs(lines \\ 30) do
    if File.exists?(@log_path) do
      @log_path
      |> File.read!()
      |> String.split("\n")
      |> Enum.take(-lines)
      |> Enum.join("\n")
    else
      "No logs found at #{@log_path}."
    end
  end
end
