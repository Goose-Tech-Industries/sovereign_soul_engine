defmodule SovereignSoulEngine.AcpManagerTest do
  use ExUnit.Case, async: false
  alias SovereignSoulEngine.AcpManager

  setup do
    old = Application.fetch_env(:sovereign_soul_engine, :acp_log_path)
    dir = Path.join(System.tmp_dir!(), "sse-acp-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, "acp.log")
    Application.put_env(:sovereign_soul_engine, :acp_log_path, path)

    on_exit(fn ->
      case old do
        {:ok, value} -> Application.put_env(:sovereign_soul_engine, :acp_log_path, value)
        :error -> Application.delete_env(:sovereign_soul_engine, :acp_log_path)
      end

      File.rm_rf!(dir)
    end)

    %{path: path, dir: dir}
  end

  test "log tails count real lines, including newline-terminated logs", %{path: path} do
    assert AcpManager.get_logs() == "No logs found at #{path}."
    File.write!(path, "first\nsecond\nthird\n")
    assert AcpManager.get_logs(2) == "second\nthird"
    assert AcpManager.get_logs(0) == ""
    assert AcpManager.get_logs(20) == "first\nsecond\nthird"
  end

  test "unreadable logs return an error message", %{dir: dir} do
    Application.put_env(:sovereign_soul_engine, :acp_log_path, dir)
    assert AcpManager.get_logs() =~ "Unable to read logs:"
  end

  test "TCP probe detects a listener and its closure" do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    on_exit(fn -> :gen_tcp.close(listener) end)
    {:ok, port} = :inet.port(listener)
    assert AcpManager.running?(port)
    :ok = :gen_tcp.close(listener)
    refute AcpManager.running?(port)
  end

  test "already running start does not launch another process" do
    assert AcpManager.start(probe: fn -> true end, launch: fn -> flunk("duplicate launch") end)
  end

  test "startup probes after launch and wait" do
    Process.put(:acp_probes, [false, true])

    probe = fn ->
      [head | tail] = Process.get(:acp_probes)
      Process.put(:acp_probes, tail)
      head
    end

    assert AcpManager.start(
             probe: probe,
             launch: fn ->
               send(self(), :launched)
               {:ok, self()}
             end,
             wait: fn 1000 -> assert_received :launched end
           )

    assert Process.get(:acp_probes) == []
  end

  test "startup reports failed launch and failed readiness" do
    refute AcpManager.start(probe: fn -> false end, launch: fn -> {:error, :unavailable} end)

    refute AcpManager.start(
             probe: fn -> false end,
             launch: fn -> {:ok, self()} end,
             wait: fn _ -> :ok end
           )

    refute AcpManager.start(probe: fn -> false end, launch: fn -> :erlang.error(:enoent) end)
  end

  test "shutdown checks command result and actual readiness" do
    command = fn "pkill", ["-f", "opencode acp"] -> {"", 0} end
    assert AcpManager.stop(command: command, wait: fn 500 -> :ok end, probe: fn -> false end)
    refute AcpManager.stop(command: command, wait: fn _ -> :ok end, probe: fn -> true end)
    refute AcpManager.stop(command: fn _, _ -> {"denied", 2} end)
    refute AcpManager.stop(command: fn _, _ -> :erlang.error(:enoent) end)
  end

  test "restart only launches after confirmed shutdown" do
    refute AcpManager.restart(
             command: fn _, _ -> {"denied", 2} end,
             launch: fn -> flunk("unsafe restart") end
           )

    Process.put(:acp_probes, [false, false, true])

    probe = fn ->
      [head | tail] = Process.get(:acp_probes)
      Process.put(:acp_probes, tail)
      head
    end

    assert AcpManager.restart(
             command: fn _, _ -> {"", 1} end,
             probe: probe,
             launch: fn -> {:ok, self()} end,
             wait: fn _ -> :ok end
           )

    assert Process.get(:acp_probes) == []
  end
end
