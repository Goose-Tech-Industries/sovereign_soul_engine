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
end
