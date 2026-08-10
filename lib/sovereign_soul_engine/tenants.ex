defmodule SovereignSoulEngine.Tenants do
  @moduledoc """
  Context for managing external systems allowed to call `/sse/api/*` — one
  row per API key. `external_source` doubles as the tenant's identity: it's
  the same value every existing request already carries (`npc_chat`,
  `ambient_chat` bodies), so authenticating a request also tells us which
  tenant's data it's allowed to touch.

  The plaintext API key only ever exists at generation time (`create_tenant/3`,
  `rotate_key/1`) — only its SHA-256 hash is stored, so there is no way to
  recover a lost key, only to rotate it.
  """

  import Ecto.Query, warn: false
  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Tenants.Tenant
  alias SovereignSoulEngine.LLM.ProviderCascade

  # Encrypted at rest with the app's own secret_key_base — same primitive
  # Phoenix itself uses for signed/encrypted session cookies. Never store
  # a tenant's plaintext key; it only exists in memory at set_byok/resolve_byok time.
  @byok_encryption_context "sse.tenant_byok"

  def list_tenants, do: Repo.all(Tenant)
  def get_tenant!(id), do: Repo.get!(Tenant, id)

  @doc "Returns `{:ok, tenant, plaintext_key}` — the plaintext is shown once and never stored."
  def create_tenant(name, external_source, rate_limit_per_minute \\ 60) do
    {plaintext_key, key_hash, key_prefix} = generate_key()

    %Tenant{}
    |> Tenant.changeset(%{
      name: name,
      external_source: external_source,
      api_key_hash: key_hash,
      api_key_prefix: key_prefix,
      rate_limit_per_minute: rate_limit_per_minute
    })
    |> Repo.insert()
    |> case do
      {:ok, tenant} -> {:ok, tenant, plaintext_key}
      error -> error
    end
  end

  @doc "Generates a new key for an existing tenant, invalidating the old one. Returns `{:ok, tenant, plaintext_key}`."
  def rotate_key(%Tenant{} = tenant) do
    {plaintext_key, key_hash, key_prefix} = generate_key()

    tenant
    |> Tenant.changeset(%{api_key_hash: key_hash, api_key_prefix: key_prefix})
    |> Repo.update()
    |> case do
      {:ok, tenant} -> {:ok, tenant, plaintext_key}
      error -> error
    end
  end

  @doc "Looks up the active tenant owning this plaintext key, or nil if it's missing/invalid/deactivated."
  def authenticate(plaintext_key) do
    key_hash = hash_key(plaintext_key)
    Repo.get_by(Tenant, api_key_hash: key_hash, active: true)
  end

  def deactivate_tenant(%Tenant{} = tenant) do
    tenant |> Tenant.changeset(%{active: false}) |> Repo.update()
  end

  @doc "Atomic increment — safe under concurrent requests, no read-modify-write race."
  def record_llm_call(%Tenant{id: id}) do
    from(t in Tenant, where: t.id == ^id)
    |> Repo.update_all(inc: [llm_call_count: 1])
  end

  @doc """
  Configures a tenant's own LLM provider key. Test-calls the real provider
  with the given key before saving anything — a BYOK key that's silently
  broken until a real player's first message is a bad experience worth one
  extra request at provisioning time. Returns `{:error, :invalid_provider}`,
  `{:error, :key_test_failed, reason}`, or `{:ok, tenant}`.
  """
  def set_byok(%Tenant{} = tenant, provider_name, plaintext_key) do
    case ProviderCascade.provider_by_name(provider_name) do
      nil ->
        {:error, :invalid_provider}

      provider_module ->
        test_input = %{
          system: "Respond with a tiny json object.",
          messages: [%{role: "user", content: "Reply with json: {\"ok\": true}"}]
        }

        case provider_module.respond(test_input, api_key: plaintext_key) do
          {:ok, _} ->
            tenant
            |> Tenant.byok_changeset(%{
              byok_provider: provider_name,
              byok_api_key_encrypted: encrypt(plaintext_key)
            })
            |> Repo.update()

          {:error, reason} ->
            {:error, :key_test_failed, reason}
        end
    end
  end

  def clear_byok(%Tenant{} = tenant) do
    tenant |> Tenant.clear_byok_changeset() |> Repo.update()
  end

  @doc "Returns `{:ok, provider_module, plaintext_key}` if this tenant has BYOK configured, else `:not_configured`."
  def resolve_byok(%Tenant{byok_provider: nil}), do: :not_configured

  def resolve_byok(%Tenant{byok_provider: provider_name, byok_api_key_encrypted: encrypted}) do
    case ProviderCascade.provider_by_name(provider_name) do
      nil -> :not_configured
      provider_module -> {:ok, provider_module, decrypt(encrypted)}
    end
  end

  defp encrypt(plaintext), do: Plug.Crypto.encrypt(secret_key_base(), @byok_encryption_context, plaintext)
  defp decrypt(ciphertext) do
    {:ok, plaintext} = Plug.Crypto.decrypt(secret_key_base(), @byok_encryption_context, ciphertext)
    plaintext
  end

  defp secret_key_base do
    Application.fetch_env!(:sovereign_soul_engine, SovereignSoulEngineWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end

  defp generate_key do
    plaintext_key = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    {plaintext_key, hash_key(plaintext_key), String.slice(plaintext_key, 0, 8)}
  end

  defp hash_key(plaintext_key) do
    :crypto.hash(:sha256, plaintext_key) |> Base.encode16(case: :lower)
  end
end
