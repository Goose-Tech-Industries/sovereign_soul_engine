defmodule SovereignSoulEngineWeb.AcpSocialLogCallbacksTest do
  use SovereignSoulEngine.DataCase, async: false

  alias SovereignSoulEngineWeb.AcpSocialLogLive

  test "social log handles empty scene selection and pubsub refreshes" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    {:ok, socket} = AcpSocialLogLive.mount(%{}, %{}, socket)
    assert socket.assigns.selected_scene == nil
    assert socket.assigns.messages == []
    {:noreply, socket} = AcpSocialLogLive.handle_params(%{"id" => "missing"}, "", socket)
    assert socket.assigns.selected_scene == nil
    {:noreply, socket} = AcpSocialLogLive.handle_info({:scenes_updated, %{}}, socket)
    {:noreply, socket} = AcpSocialLogLive.handle_info({:new_message, %{}}, socket)
    {:noreply, socket} = AcpSocialLogLive.handle_info(:unknown, socket)
    assert socket.assigns.messages == []
  end
end
