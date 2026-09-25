defmodule SovereignSoulEngine.AcpManagerTest do
  use ExUnit.Case, async: false

  alias SovereignSoulEngine.AcpManager

  test "reports false when the ACP port is not listening" do
    refute AcpManager.running?()
  end

  test "returns a safe message when the ACP log is absent" do
    assert AcpManager.get_logs() == "No logs found at /root/.config/opencode/acp.log."
  end

  test "returns an empty string when requesting zero log lines and no log exists" do
    assert AcpManager.get_logs(0) == "No logs found at /root/.config/opencode/acp.log."
  end

  test "reads the configured log path and returns the requested tail" do
    path = Path.join(System.tmp_dir!(), "sse-acp-#{System.unique_integer([:positive])}.log")
    File.write!(path, "first\nsecond\nthird\n")
    Application.put_env(:sovereign_soul_engine, :acp_log_path, path)

    on_exit(fn ->
      Application.delete_env(:sovereign_soul_engine, :acp_log_path)
      File.rm(path)
    end)

    assert AcpManager.get_logs(2) == "third\n"
  end

  test "running accepts a configured unused port" do
    refute AcpManager.running?(65_432)
  end
end
