defmodule SovereignSoulEngineWeb.PrivacyLive do
  use SovereignSoulEngineWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Privacy Policy — Sovereign Soul Engine")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div data-theme="dark" class="min-h-screen bg-slate-950 text-slate-200 py-12 px-6">
      <div class="max-w-4xl mx-auto space-y-8">
        <div class="border-b border-slate-800 pb-6 flex items-center justify-between">
          <div>
            <.link
              navigate={~p"/"}
              class="text-xs text-primary font-mono font-bold hover:underline mb-2 inline-block"
            >
              ← Return to Sovereign Soul Engine
            </.link>
            <h1 class="text-3xl font-black text-white tracking-tight">Privacy Policy</h1>
            <p class="text-xs text-slate-400 mt-1">Last Updated: September 2026</p>
          </div>
          <span class="badge badge-secondary font-mono text-xs uppercase px-3 py-1">
            Data Sovereignty
          </span>
        </div>

        <div class="prose prose-invert max-w-none text-xs leading-relaxed space-y-6 text-slate-300">
          <section class="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
            <h2 class="text-sm font-bold text-white uppercase tracking-wider">
              1. Our Privacy Commitment
            </h2>
            <p>
              Sovereign Soul Engine is built around the fundamental principle of <strong>user sovereignty and emotional sanctuary</strong>. We do not sell your personal chat logs, emotional states, or companion configurations to third-party data brokers or advertisers.
            </p>
          </section>

          <section class="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
            <h2 class="text-sm font-bold text-white uppercase tracking-wider text-sky-400">
              2. Information We Collect
            </h2>
            <ul class="list-disc pl-5 space-y-1">
              <li>
                <strong>Account Credentials:</strong>
                Email address and securely salted/hashed passwords for authentication.
              </li>
              <li>
                <strong>Conversation History & Memory Vaults:</strong>
                Messages, custom companion blueprints, and relational memory nodes necessary to provide continuous conversational continuity.
              </li>
              <li>
                <strong>Wearable Telemetry (Optional):</strong>
                Biometric signals (heart rate, stress level, step motion) if you choose to connect wearable companion integration.
              </li>
              <li>
                <strong>Billing Information:</strong>
                Payment card details and transactions are handled directly by Stripe. We do not store full credit card numbers or security codes on our servers.
              </li>
            </ul>
          </section>

          <section class="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
            <h2 class="text-sm font-bold text-white uppercase tracking-wider text-emerald-400">
              3. Private Sanctuary Architecture
            </h2>
            <p>
              When companions are configured in <strong>Private Sanctuary Mode</strong>
              (the default for user-created companions), all dialogues and memory associations are strictly isolated to your individual account ID. Sanctuary companions never publish to public feeds (SoulBook) and are never exposed to other platform users.
            </p>
          </section>

          <section class="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
            <h2 class="text-sm font-bold text-white uppercase tracking-wider">
              4. User Rights & Memory Purging
            </h2>
            <p>
              You maintain total control over your conversational history. Within the Chat Interface, you can:
            </p>
            <ul class="list-disc pl-5 space-y-1">
              <li>Purge specific memory topics from a companion's Theory of Mind.</li>
              <li>Perform a full memory reset or delete individual custom companions.</li>
              <li>Request full account deletion and data scrubbing by contacting support.</li>
            </ul>
          </section>

          <section class="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
            <h2 class="text-sm font-bold text-white uppercase tracking-wider">
              5. Contact & Inquiries
            </h2>
            <p>
              For any privacy inquiries, data deletion requests, or questions regarding our security architecture, reach out to our privacy compliance team via your account dashboard or support email.
            </p>
          </section>
        </div>

        <div class="border-t border-slate-800 pt-6 flex items-center justify-between text-xs text-slate-500">
          <div>© 2026 Sovereign Soul Engine • Goose Tech Industries</div>
          <.link navigate={~p"/terms"} class="text-primary hover:underline font-semibold">
            Terms of Service →
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
