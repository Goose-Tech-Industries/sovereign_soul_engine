defmodule SovereignSoulEngineWeb.CognitionLive do
  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Cognition.{Approvals, Checkpoints}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_state(socket)}
  end

  @impl true
  def handle_event("refresh", _params, socket), do: {:noreply, assign_state(socket)}

  defp assign_state(socket) do
    socket
    |> assign(:page_title, "Cognition Inspector")
    |> assign(:approvals, Approvals.recent())
    |> assign(:checkpoints, Checkpoints.recent())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <div>
            <.link navigate={~p"/sse"} class="text-sm text-base-content/60">← Dashboard</.link>
            <h1 class="text-2xl font-bold text-base-content mt-1">Cognition Inspector</h1>
            <p class="text-sm text-base-content/50 mt-1">
              Checkpoints and approval state for external actions. Private thoughts are never shown here.
            </p>
          </div>
          <button phx-click="refresh" class="btn btn-sm btn-outline">Refresh</button>
        </div>

        <section class="space-y-2">
          <h2 class="text-lg font-semibold">Approval requests</h2>
          <div :if={@approvals == []} class="text-sm text-base-content/50">No approval requests.</div>
          <div
            :for={approval <- @approvals}
            class="rounded-lg border border-base-300 p-3 bg-base-200/30"
          >
            <div class="flex justify-between gap-3">
              <span class="font-medium">{approval.operation}</span>
              <span class="badge badge-outline">{approval.status}</span>
            </div>
            <p class="text-xs text-base-content/50 mt-1">{approval.id}</p>
            <p :if={approval.execution_status} class="text-xs mt-1">
              Execution: {approval.execution_status}
            </p>
          </div>
        </section>

        <section class="space-y-2">
          <h2 class="text-lg font-semibold">Cognition checkpoints</h2>
          <div :if={@checkpoints == []} class="text-sm text-base-content/50">No checkpoints.</div>
          <div
            :for={checkpoint <- @checkpoints}
            class="rounded-lg border border-base-300 p-3 bg-base-200/30"
          >
            <div class="flex justify-between gap-3">
              <span class="font-medium">{checkpoint.thread_id}</span>
              <span class="badge badge-outline">{checkpoint.status}</span>
            </div>
            <p class="text-xs text-base-content/50 mt-1">
              Version {checkpoint.version} · {checkpoint.id}
            </p>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
