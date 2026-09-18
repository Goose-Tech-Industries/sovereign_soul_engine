defmodule SovereignSoulEngineWeb.BillingLive do
  @moduledoc """
  Stripe Subscription Billing & Age Verification Control Center.

  Allows users to:
  - Subscribe to the $14.99/mo Companion tier or $19.99/mo Archon (18+ Uncensored) tier.
  - Complete Date-of-Birth (DOB) and Informed Consent age verification.
  - View their active commercial safe-harbor status and content maturity level.
  """

  use SovereignSoulEngineWeb, :live_view

  alias SovereignSoulEngine.Billing
  alias SovereignSoulEngine.Characters

  @impl true
  def mount(_params, _session, socket) do
    player =
      Characters.get_character_by_slug("goose") ||
        case Characters.create_character(%{
               name: "Goose",
               slug: "goose",
               kind: "player",
               status: "active",
               description: "Primary player character"
             }) do
          {:ok, p} -> p
          {:error, _} -> List.first(Characters.list_characters())
        end

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, Billing.pubsub_topic())
      Phoenix.PubSub.subscribe(SovereignSoulEngine.PubSub, Billing.AgeVerification.pubsub_topic())
    end

    subscription = Billing.get_subscription(player)
    age_status = Billing.get_age_status(player)
    tiers = Billing.list_tiers()

    socket =
      socket
      |> assign(:page_title, "Billing & 18+ Verification — Sovereign Soul Engine")
      |> assign(:player, player)
      |> assign(:subscription, subscription)
      |> assign(:age_status, age_status)
      |> assign(:tiers, tiers)
      |> assign(:dob_year, "2000")
      |> assign(:dob_month, "01")
      |> assign(:dob_day, "01")
      |> assign(:certify_18, false)
      |> assign(:ai_disclaimer, false)
      |> assign(:mature_consent, false)
      |> assign(:verifying?, false)
      |> assign(:success_banner?, false)
      |> assign(:success_tier, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"session_id" => session_id} = params, _uri, socket) do
    # User was redirected back from completed checkout
    tier_id = Map.get(params, "tier", "companion_1499")
    Billing.handle_checkout_completed(%{tier: tier_id, subscription: session_id})

    # Refresh status
    subscription = Billing.get_subscription(socket.assigns.player.id)
    age_status = Billing.get_age_status(socket.assigns.player.id)

    socket =
      socket
      |> assign(:subscription, subscription)
      |> assign(:age_status, age_status)
      |> assign(:success_banner?, true)
      |> assign(:success_tier, tier_id)
      |> put_flash(:info, "Stripe checkout successful! Your #{subscription.tier_name} subscription is now active.")

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # --- Checkout Events --------------------------------------------------------

  @impl true
  def handle_event("checkout_tier", %{"tier_id" => tier_id}, socket) do
    player = socket.assigns.player

    case Billing.create_checkout_session(tier_id, player) do
      {:ok, %{url: checkout_url, mode: :live}} ->
        {:noreply, redirect(socket, external: checkout_url)}

      {:ok, %{url: mock_redirect_url, mode: :mock}} ->
        # Instant development redirect for frictionless local testing
        {:noreply, redirect(socket, to: mock_redirect_url)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to initiate Stripe checkout: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("activate_mock_tier", %{"tier_id" => tier_id}, socket) do
    player = socket.assigns.player

    case Billing.set_subscription(player, tier_id) do
      {:ok, updated_sub} ->
        age_status = Billing.get_age_status(player.id)

        socket =
          socket
          |> assign(:subscription, updated_sub)
          |> assign(:age_status, age_status)
          |> assign(:success_banner?, true)
          |> assign(:success_tier, tier_id)
          |> put_flash(:info, "Activated #{updated_sub.tier_name}!")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to activate tier: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("downgrade_free", _params, socket) do
    player = socket.assigns.player
    {:ok, updated_sub} = Billing.set_subscription(player, "free")
    age_status = Billing.get_age_status(player)

    socket =
      socket
      |> assign(:subscription, updated_sub)
      |> assign(:age_status, age_status)
      |> put_flash(:info, "Downgraded to Community Free tier.")

    {:noreply, socket}
  end

  # --- Age Verification Events ------------------------------------------------

  @impl true
  def handle_event("update_dob", %{"year" => y, "month" => m, "day" => d}, socket) do
    {:noreply,
     socket
     |> assign(:dob_year, y)
     |> assign(:dob_month, m)
     |> assign(:dob_day, d)}
  end

  @impl true
  def handle_event("submit_age_verification", params, socket) do
    player = socket.assigns.player

    year = Map.get(params, "year", socket.assigns.dob_year)
    month = Map.get(params, "month", socket.assigns.dob_month) |> String.pad_leading(2, "0")
    day = Map.get(params, "day", socket.assigns.dob_day) |> String.pad_leading(2, "0")

    dob_string = "#{year}-#{month}-#{day}"

    attestations = %{
      "certify_18" => Map.get(params, "certify_18") == "on",
      "ai_disclaimer" => Map.get(params, "ai_disclaimer") == "on",
      "mature_consent" => Map.get(params, "mature_consent") == "on"
    }

    case Billing.verify_age_by_dob(player, dob_string, attestations) do
      {:ok, _verif} ->
        age_status = Billing.get_age_status(player)

        socket =
          socket
          |> assign(:age_status, age_status)
          |> put_flash(:info, "Age verification confirmed (18+). Mature roleplay and M-rated content unlocked!")

        {:noreply, socket}

      {:error, _code, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("dismiss_success_banner", _params, socket) do
    {:noreply, assign(socket, :success_banner?, false)}
  end

  # --- PubSub Listeners -------------------------------------------------------

  @impl true
  def handle_info({:subscription_updated, _player_id, _sub}, socket) do
    subscription = Billing.get_subscription(socket.assigns.player)
    age_status = Billing.get_age_status(socket.assigns.player)

    {:noreply,
     socket
     |> assign(:subscription, subscription)
     |> assign(:age_status, age_status)}
  end

  @impl true
  def handle_info({:age_verified, _player_id, _verif}, socket) do
    age_status = Billing.get_age_status(socket.assigns.player)
    {:noreply, assign(socket, :age_status, age_status)}
  end

  # --- Template ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-950 text-slate-100 font-sans antialiased pb-20 lg:pb-12">
      <%!-- Navigation Header --%>
      <header class="border-b border-slate-800 bg-slate-950/90 backdrop-blur-md px-6 py-4 flex items-center justify-between sticky top-0 z-30">
        <div class="flex items-center gap-3">
          <.link navigate={~p"/sse/chat"} class="btn btn-ghost btn-xs text-slate-400 hover:text-white flex items-center gap-1.5">
            <.icon name="hero-arrow-left" class="size-4" />
            <span>Chat</span>
          </.link>

          <div class="h-5 w-px bg-slate-800" />

          <div>
            <h1 class="text-base font-extrabold text-white flex items-center gap-2">
              <span class="text-primary">💳</span>
              <span>Billing & 18+ Verification</span>
            </h1>
            <p class="text-[11px] text-slate-400">
              Stripe Subscriptions ($14.99 / $19.99) • Commercial Safe-Harbor Age Gate
            </p>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <.link navigate={~p"/sse/feed"} class="btn btn-ghost btn-xs text-slate-400 hover:text-white hidden sm:inline-flex">
            <span>📰 Feed</span>
          </.link>
          <.link navigate={~p"/sse/acp"} class="btn btn-ghost btn-xs text-slate-400 hover:text-white hidden sm:inline-flex">
            <span>⚙️ Studio</span>
          </.link>
        </div>
      </header>

      <%!-- Flash Banners --%>
      <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
        <div class="bg-emerald-500/20 border-b border-emerald-500/30 text-emerald-300 text-xs py-2.5 px-6 font-medium flex items-center gap-2">
          <.icon name="hero-check-circle" class="size-4 text-emerald-400" />
          <span>{flash}</span>
        </div>
      <% end %>
      <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
        <div class="bg-rose-500/20 border-b border-rose-500/30 text-rose-300 text-xs py-2.5 px-6 font-medium flex items-center gap-2">
          <.icon name="hero-exclamation-triangle" class="size-4 text-rose-400" />
          <span>{flash}</span>
        </div>
      <% end %>

      <main class="max-w-5xl mx-auto p-6 space-y-10 pt-8">
        <%!-- Account Status Overview Card --%>
        <div class="p-6 rounded-3xl bg-slate-900 border border-slate-800 shadow-2xl flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
          <div class="flex items-center gap-4">
            <div class="w-14 h-14 rounded-2xl bg-gradient-to-tr from-primary to-purple-600 flex items-center justify-center text-white text-2xl font-bold shadow-lg shadow-primary/20">
              👑
            </div>
            <div>
              <div class="flex items-center gap-2">
                <span class="text-lg font-black text-white">{@player.name}</span>
                <span class="badge badge-sm font-mono text-[10px] uppercase font-bold bg-slate-800 text-slate-300">
                  @{@player.slug}
                </span>
                <span class={[
                  "badge badge-sm font-mono text-[10px] uppercase font-bold",
                  if(@subscription.tier_id == "archon_1999", do: "badge-error text-rose-200", else: if(@subscription.tier_id == "companion_1499", do: "badge-primary text-primary-content", else: "badge-ghost text-slate-400"))
                ]}>
                  {@subscription.tier_name}
                </span>
              </div>
              <p class="text-xs text-slate-400 mt-1">
                Active Plan: <span class="font-bold text-white">${@subscription.price_usd}/mo</span>
                • Content Maturity: <span class="font-bold uppercase text-primary">{@subscription.maturity_rating}</span>
              </p>
            </div>
          </div>

          <%!-- Age Verification Status Pill --%>
          <div class="flex flex-col items-start md:items-end gap-1.5">
            <%= if @age_status.verified? do %>
              <div class="flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-emerald-500/15 border border-emerald-500/40 text-emerald-300 text-xs font-bold">
                <.icon name="hero-check-badge" class="size-4 text-emerald-400" />
                <span>Verified 18+ Adult Status</span>
              </div>
              <span class="text-[10px] text-slate-500 font-mono">
                Method: {@age_status.method}
              </span>
            <% else %>
              <div class="flex items-center gap-2 px-3.5 py-1.5 rounded-xl bg-amber-500/15 border border-amber-500/40 text-amber-300 text-xs font-bold">
                <.icon name="hero-exclamation-circle" class="size-4 text-amber-400" />
                <span>18+ Age Unverified</span>
              </div>
              <span class="text-[10px] text-slate-500 font-mono">
                Mature & Adult Cinema Restricted
              </span>
            <% end %>
          </div>
        </div>

        <%!-- The Two Core Monetization Tiers ($14.99 & $19.99) --%>
        <div class="space-y-4">
          <div class="text-center space-y-1">
            <h2 class="text-2xl font-black text-white">Select Your Sovereign Tier</h2>
            <p class="text-xs text-slate-400">
              Powered by Stripe. Commercial credit card payment qualifies as commercial age verification under safe-harbor guidelines.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-8 pt-2">
            <%= for tier <- @tiers do %>
              <% is_current = @subscription.tier_id == tier.id %>
              <div class={[
                "p-8 rounded-3xl border flex flex-col justify-between space-y-6 relative transition-all duration-200",
                if(tier.id == "archon_1999", do: "bg-gradient-to-b from-rose-950/20 to-slate-900 border-rose-500/40 shadow-2xl shadow-rose-950/50", else: "bg-slate-900/90 border-slate-800 shadow-xl"),
                if(is_current, do: "ring-2 ring-primary")
              ]}>
                <%= if is_current do %>
                  <span class="absolute -top-3 left-6 px-3 py-1 rounded-full text-[10px] font-mono font-bold bg-primary text-primary-content uppercase tracking-wider">
                    Current Plan
                  </span>
                <% end %>

                <div class="space-y-4">
                  <div class="flex items-center justify-between">
                    <div>
                      <h3 class="text-xl font-extrabold text-white">{tier.name}</h3>
                      <p class="text-xs text-slate-400 mt-0.5">{tier.tagline}</p>
                    </div>
                    <span class={["badge badge-sm font-mono font-bold uppercase", tier.badge_class]}>
                      {tier.badge}
                    </span>
                  </div>

                  <div class="flex items-baseline gap-1.5 pt-2">
                    <span class="text-4xl font-black text-white">${tier.price_usd}</span>
                    <span class="text-xs text-slate-400 font-medium">/ {tier.interval}</span>
                  </div>

                  <ul class="text-xs space-y-2.5 text-slate-300 pt-2 border-t border-slate-800">
                    <%= for feature <- tier.features do %>
                      <li class="flex items-start gap-2">
                        <.icon name="hero-check" class="size-4 text-emerald-400 shrink-0 mt-0.5" />
                        <span>{feature}</span>
                      </li>
                    <% end %>
                  </ul>
                </div>

                <div class="space-y-2 pt-4">
                  <%= if is_current do %>
                    <button disabled class="btn btn-sm btn-outline btn-block border-slate-700 text-slate-400">
                      Active on Your Account
                    </button>
                  <% else %>
                    <button
                      phx-click="checkout_tier"
                      phx-value-tier_id={tier.id}
                      class={[
                        "btn btn-sm btn-block font-bold text-xs shadow-lg",
                        if(tier.id == "archon_1999", do: "btn-error text-white shadow-rose-600/30", else: "btn-primary shadow-primary/30")
                      ]}
                    >
                      <.icon name="hero-credit-card" class="size-4" />
                      <span>Subscribe with Stripe (${tier.price_usd}/mo)</span>
                    </button>
                  <% end %>

                  <%!-- Quick Dev Toggle button --%>
                  <button
                    phx-click="activate_mock_tier"
                    phx-value-tier_id={tier.id}
                    class="btn btn-ghost btn-xs btn-block text-[10px] text-slate-500 hover:text-slate-300"
                  >
                    ⚡ Test Switch to {tier.name} (Dev Bypass)
                  </button>
                </div>
              </div>
            <% end %>
          </div>

          <div class="text-center pt-2">
            <button
              phx-click="downgrade_free"
              class="text-xs text-slate-500 hover:text-slate-300 underline"
            >
              Downgrade to Community Free Tier ($0)
            </button>
          </div>
        </div>

        <%!-- Standalone Age Verification Form (DOB + Informed Consent) --%>
        <div class="p-8 rounded-3xl bg-slate-900 border border-slate-800 space-y-6 shadow-2xl">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-amber-500/20 text-amber-400 flex items-center justify-center font-bold text-lg border border-amber-500/30">
              🔞
            </div>
            <div>
              <h3 class="text-base font-bold text-white">Date-of-Birth & Informed Consent Verification</h3>
              <p class="text-xs text-slate-400">
                Required for M-rated swearing, psychological horror, and 18+ adult intimate scenes.
              </p>
            </div>
          </div>

          <%= if @age_status.verified? do %>
            <div class="p-4 rounded-2xl bg-emerald-950/40 border border-emerald-800/50 flex items-center justify-between gap-4">
              <div class="flex items-center gap-3">
                <.icon name="hero-check-circle" class="size-6 text-emerald-400" />
                <div>
                  <div class="text-xs font-bold text-emerald-200">Your 18+ status is active and verified</div>
                  <div class="text-[11px] text-slate-400">Verified via {@age_status.method} on {@age_status.verified_at}</div>
                </div>
              </div>
              <span class="badge badge-sm badge-success font-bold text-[10px]">VERIFIED 18+</span>
            </div>
          <% else %>
            <form phx-submit="submit_age_verification" class="space-y-5">
              <%!-- DOB Pickers --%>
              <div class="space-y-2">
                <label class="text-xs font-bold text-slate-300 uppercase tracking-wider">Date of Birth</label>
                <div class="grid grid-cols-3 gap-3">
                  <div>
                    <span class="text-[10px] text-slate-500">Year</span>
                    <input
                      type="number"
                      name="year"
                      min="1920"
                      max="2030"
                      value={@dob_year}
                      class="input input-sm input-bordered w-full bg-slate-950 border-slate-700 text-xs font-mono"
                      required
                    />
                  </div>
                  <div>
                    <span class="text-[10px] text-slate-500">Month</span>
                    <input
                      type="number"
                      name="month"
                      min="1"
                      max="12"
                      value={@dob_month}
                      class="input input-sm input-bordered w-full bg-slate-950 border-slate-700 text-xs font-mono"
                      required
                    />
                  </div>
                  <div>
                    <span class="text-[10px] text-slate-500">Day</span>
                    <input
                      type="number"
                      name="day"
                      min="1"
                      max="31"
                      value={@dob_day}
                      class="input input-sm input-bordered w-full bg-slate-950 border-slate-700 text-xs font-mono"
                      required
                    />
                  </div>
                </div>
              </div>

              <%!-- Informed Consent Checkboxes --%>
              <div class="space-y-3 pt-2">
                <label class="flex items-start gap-3 cursor-pointer p-3 rounded-xl bg-slate-950/80 border border-slate-800">
                  <input type="checkbox" name="certify_18" class="checkbox checkbox-sm checkbox-primary mt-0.5" required />
                  <span class="text-xs text-slate-300 leading-relaxed">
                    <strong>Majority Certification:</strong> I certify under penalty of terms suspension and perjury that I am at least 18 years of age.
                  </span>
                </label>

                <label class="flex items-start gap-3 cursor-pointer p-3 rounded-xl bg-slate-950/80 border border-slate-800">
                  <input type="checkbox" name="ai_disclaimer" class="checkbox checkbox-sm checkbox-primary mt-0.5" required />
                  <span class="text-xs text-slate-300 leading-relaxed">
                    <strong>AI Software Entity Disclosure:</strong> I understand that Sovereign Souls are generative artificial intelligence software entities and NOT licensed medical doctors, therapists, or human persons.
                  </span>
                </label>

                <label class="flex items-start gap-3 cursor-pointer p-3 rounded-xl bg-slate-950/80 border border-slate-800">
                  <input type="checkbox" name="mature_consent" class="checkbox checkbox-sm checkbox-primary mt-0.5" required />
                  <span class="text-xs text-slate-300 leading-relaxed">
                    <strong>Mature & Unrestricted Content Consent:</strong> I voluntarily consent to mature (M-rated) and adult themes, including swearing, dark fantasy violence, and adult roleplay.
                  </span>
                </label>
              </div>

              <button type="submit" class="btn btn-sm btn-accent w-full font-bold text-xs">
                <.icon name="hero-shield-check" class="size-4" />
                <span>Confirm & Complete 18+ Age Verification</span>
              </button>
            </form>
          <% end %>
        </div>
      </main>

      <%!-- Mobile Bottom Navigation Dock --%>
      <nav class="lg:hidden fixed bottom-0 left-0 right-0 z-40 bg-slate-950/95 backdrop-blur-lg border-t border-slate-800 px-4 py-2 flex items-center justify-around">
        <.link navigate={~p"/sse/chat"} class="flex flex-col items-center gap-0.5 text-slate-400 hover:text-white">
          <span class="text-lg">💬</span>
          <span class="text-[10px] font-medium">Chat</span>
        </.link>

        <.link navigate={~p"/sse/feed"} class="flex flex-col items-center gap-0.5 text-slate-400 hover:text-white">
          <span class="text-lg">📰</span>
          <span class="text-[10px] font-medium">Feed</span>
        </.link>

        <.link navigate={~p"/sse/acp"} class="flex flex-col items-center gap-0.5 text-slate-400 hover:text-white">
          <span class="text-lg">⚙️</span>
          <span class="text-[10px] font-medium">Studio</span>
        </.link>

        <.link navigate={~p"/sse/billing"} class="flex flex-col items-center gap-0.5 text-primary font-bold">
          <span class="text-lg">💳</span>
          <span class="text-[10px]">Billing</span>
        </.link>

        <.link navigate={~p"/sse/acp/moderation"} class="flex flex-col items-center gap-0.5 text-slate-400 hover:text-white">
          <span class="text-lg">🛡️</span>
          <span class="text-[10px] font-medium">Shield</span>
        </.link>
      </nav>
    </div>
    """
  end
end
