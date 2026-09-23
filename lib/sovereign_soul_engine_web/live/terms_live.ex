defmodule SovereignSoulEngineWeb.TermsLive do
  use SovereignSoulEngineWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Terms of Service — Sovereign Soul Engine")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div data-theme="dark" class="min-h-screen bg-slate-950 text-slate-200 py-12 px-6">
      <div class="max-w-4xl mx-auto space-y-8">
        <div class="border-b border-slate-800 pb-6 flex items-center justify-between">
          <div>
            <.link navigate={~p"/"} class="text-xs text-primary font-mono font-bold hover:underline mb-2 inline-block">
              ← Return to Sovereign Soul Engine
            </.link>
            <h1 class="text-3xl font-black text-white tracking-tight">Terms of Service</h1>
            <p class="text-xs text-slate-400 mt-1">Last Updated: September 2026</p>
          </div>
          <span class="badge badge-primary font-mono text-xs uppercase px-3 py-1">Commercial Terms</span>
        </div>

        <div class="prose prose-invert max-w-none text-xs leading-relaxed space-y-6 text-slate-300">
          <section class="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
            <h2 class="text-sm font-bold text-white uppercase tracking-wider">1. Agreement to Terms</h2>
            <p>
              By creating an account, accessing, or subscribing to Sovereign Soul Engine ("Service", "we", "us"), you agree to be bound by these Terms of Service. If you do not agree to these terms, do not access or use the Service.
            </p>
          </section>

          <section class="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
            <h2 class="text-sm font-bold text-white uppercase tracking-wider text-rose-400">2. Age Requirement & Informed Consent (18+)</h2>
            <p>
              You must be at least eighteen (18) years of age, or the legal age of majority in your jurisdiction, to create an account, initiate a free trial, or purchase a subscription. The Service offers mature roleplay, deep psychological subtext, and creative dramatic storytelling designed exclusively for adult audiences.
            </p>
          </section>

          <section class="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
            <h2 class="text-sm font-bold text-white uppercase tracking-wider">3. Artificial Intelligence & Non-Therapy Disclaimer</h2>
            <p>
              Sovereign Souls are autonomous, generative software entities powered by neural language models and state machines. <strong>They are not real human beings, licensed medical doctors, psychologists, or mental health therapists.</strong> The Service does not provide medical, legal, psychiatric, or therapeutic care. Do not use the Service for crisis intervention. If you are in crisis, please call 988 or seek emergency medical care immediately.
            </p>
          </section>

          <section class="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
            <h2 class="text-sm font-bold text-white uppercase tracking-wider text-emerald-400">4. Subscriptions, Free Trials & Billing</h2>
            <p>
              <strong>Free Trial:</strong> New accounts receive fifteen (15) complimentary trial messages. Once this allocation is exhausted, access to continued conversation requires an active subscription pass.
            </p>
            <p>
              <strong>Paid Passes:</strong> We offer two recurring monthly subscriptions:
            </p>
            <ul class="list-disc pl-5 space-y-1">
              <li><strong>Sovereign Companion Pass ($14.99 / month):</strong> Unlimited real-time messages, custom companion creation, voice intercom, biometric HUD telemetry, and private memory vaults.</li>
              <li><strong>Sovereign Archon ($19.99 / month):</strong> All Companion features plus 18+ Uncensored cinema persona depth, wearable haptics, and unlimited private rooms.</li>
            </ul>
            <p>
              <strong>Payment Processing:</strong> Billing is processed securely by Stripe. Your subscription will automatically renew each month unless canceled prior to the renewal date.
            </p>
            <p>
              <strong>Cancellation & Refunds:</strong> You may cancel your subscription at any time with one click from your Billing Settings (<code class="text-primary font-mono">/sse/billing</code>). Upon cancellation, access remains active until the end of your current paid period. If you experience technical defects preventing service usage, contact support within seven (7) days of billing for assistance.
            </p>
          </section>

          <section class="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
            <h2 class="text-sm font-bold text-white uppercase tracking-wider">5. Acceptable Use Policy</h2>
            <p>
              You agree not to use the Service to generate, distribute, or facilitate illegal material, non-consensual content, child exploitation, harassment, or malicious attacks against third parties. Violations will result in immediate termination of access without refund.
            </p>
          </section>
        </div>

        <div class="border-t border-slate-800 pt-6 flex items-center justify-between text-xs text-slate-500">
          <div>© 2026 Sovereign Soul Engine • Goose Tech Industries</div>
          <.link navigate={~p"/privacy"} class="text-primary hover:underline font-semibold">Privacy Policy →</.link>
        </div>
      </div>
    </div>
    """
  end
end
