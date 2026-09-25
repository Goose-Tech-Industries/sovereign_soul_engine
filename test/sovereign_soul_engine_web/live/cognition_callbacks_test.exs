defmodule SovereignSoulEngineWeb.CognitionCallbacksTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngineWeb.CognitionLive

  test "cognition inspector mounts and refreshes its read models" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = CognitionLive.mount(%{}, %{}, socket)
    assert socket.assigns.page_title == "Cognition Inspector"
    assert is_list(socket.assigns.approvals)
    assert is_list(socket.assigns.checkpoints)
    {:noreply, refreshed} = CognitionLive.handle_event("refresh", %{}, socket)
    assert is_list(refreshed.assigns.approvals)
    assert is_list(refreshed.assigns.checkpoints)
  end
end
