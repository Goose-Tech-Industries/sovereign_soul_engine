defmodule SovereignSoulEngineWeb.UserLive.Settings do
  use SovereignSoulEngineWeb, :live_view

  on_mount {SovereignSoulEngineWeb.UserAuth, :require_sudo_mode}

  alias SovereignSoulEngine.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your account email address and password settings</:subtitle>
        </.header>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          spellcheck="false"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/users/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_user_email"
          spellcheck="false"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="New password"
          autocomplete="new-password"
          spellcheck="false"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
          spellcheck="false"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Save Password
        </.button>
      </.form>

      <div class="divider" />

      <div class="p-6 rounded-2xl bg-slate-900 border border-slate-800 space-y-4 text-left">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h3 class="text-base font-bold text-white flex items-center gap-2">
              <span>🔒 Living World Privacy</span>
              <span class={if @opt_out_living_world, do: "badge badge-error badge-sm font-mono", else: "badge badge-success badge-sm font-mono"}>
                {if @opt_out_living_world, do: "PRIVATE SANCTUARY", else: "LIVING WORLD ACTIVE"}
              </span>
            </h3>
            <p class="text-xs text-slate-400 mt-1 max-w-xl leading-relaxed">
              Opt out of having your companion(s) participate in the public living world. When opted out, your companion will <strong>never</strong> post to the public SoulBook social feed, never gossip with town NPCs, and will exist exclusively in your private 1-on-1 sanctuary.
            </p>
          </div>
          <div>
            <button
              phx-click="toggle_living_world_opt_out"
              class={if @opt_out_living_world, do: "btn btn-sm btn-error font-bold whitespace-nowrap", else: "btn btn-sm btn-outline font-bold whitespace-nowrap"}
            >
              {if @opt_out_living_world, do: "✓ Opted Out (Private)", else: "Opt Out of Living World"}
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:opt_out_living_world, user.opt_out_living_world || false)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_living_world_opt_out", _params, socket) do
    user = socket.assigns.current_scope.user
    new_opt_out = !user.opt_out_living_world

    case Accounts.update_user_preferences(user, %{opt_out_living_world: new_opt_out}) do
      {:ok, updated_user} ->
        msg =
          if new_opt_out do
            "Companions opted out: Your sanctuary is now private and will not appear in the living world."
          else
            "Companions opted in: Your companions can now participate in town events and social posts."
          end

        {:noreply,
         socket
         |> assign(:opt_out_living_world, new_opt_out)
         |> assign(:current_scope, SovereignSoulEngine.Accounts.Scope.for_user(updated_user))
         |> put_flash(:info, msg)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update living world privacy setting.")}
    end
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
