defmodule SovereignSoulEngine.TenantsTest do
  use SovereignSoulEngine.DataCase, async: true

  alias SovereignSoulEngine.Tenants
  alias SovereignSoulEngine.Tenants.Tenant
  alias SovereignSoulEngine.LLM.{ProviderCascade, AnthropicProvider}

  describe "tenant provisioning and key management" do
    test "create_tenant/3 returns tenant and single-use plaintext key" do
      source = "tenant_src_#{System.unique_integer([:positive])}"

      assert {:ok, %Tenant{} = tenant, plaintext_key} =
               Tenants.create_tenant("Acme Corp", source, 120)

      assert tenant.name == "Acme Corp"
      assert tenant.external_source == source
      assert tenant.rate_limit_per_minute == 120
      assert tenant.active == true
      assert tenant.llm_call_count == 0

      # Plaintext key format verification
      assert is_binary(plaintext_key)
      assert String.length(plaintext_key) >= 32
      assert tenant.api_key_prefix == String.slice(plaintext_key, 0, 8)
      assert tenant.api_key_hash =~ ~r/^[0-9a-f]{64}$/

      # Plaintext key is NOT stored in DB
      db_tenant = Tenants.get_tenant!(tenant.id)
      refute Map.has_key?(Map.from_struct(db_tenant), :plaintext_key)
      assert db_tenant.api_key_hash == tenant.api_key_hash
    end

    test "authenticate/1 recognizes authentic plaintext keys and rejects invalid ones" do
      source = "auth_src_#{System.unique_integer([:positive])}"
      {:ok, tenant, plaintext_key} = Tenants.create_tenant("Auth Corp", source)

      # Authentic key matches
      authenticated = Tenants.authenticate(plaintext_key)
      assert authenticated != nil
      assert authenticated.id == tenant.id

      # Wrong key fails
      assert Tenants.authenticate("invalid_random_api_key_value") == nil
      assert Tenants.authenticate(nil) == nil
    end

    test "rotate_key/1 invalidates old key and provisions new working key" do
      source = "rot_src_#{System.unique_integer([:positive])}"
      {:ok, tenant, key_v1} = Tenants.create_tenant("Rotate Corp", source)

      assert Tenants.authenticate(key_v1).id == tenant.id

      {:ok, rotated_tenant, key_v2} = Tenants.rotate_key(tenant)

      assert key_v1 != key_v2
      assert rotated_tenant.api_key_hash != tenant.api_key_hash

      # Old key is completely invalidated
      assert Tenants.authenticate(key_v1) == nil

      # New key authenticates successfully
      assert Tenants.authenticate(key_v2).id == tenant.id
    end

    test "deactivate_tenant/1 blocks authentication" do
      source = "deact_src_#{System.unique_integer([:positive])}"
      {:ok, tenant, plaintext_key} = Tenants.create_tenant("Deact Corp", source)

      assert Tenants.authenticate(plaintext_key) != nil

      {:ok, deactivated} = Tenants.deactivate_tenant(tenant)
      assert deactivated.active == false

      # Deactivated tenants cannot authenticate
      assert Tenants.authenticate(plaintext_key) == nil
    end

    test "record_llm_call/1 atomically increments call count" do
      source = "inc_src_#{System.unique_integer([:positive])}"
      {:ok, tenant, _key} = Tenants.create_tenant("Inc Corp", source)
      assert tenant.llm_call_count == 0

      {1, _} = Tenants.record_llm_call(tenant)
      {1, _} = Tenants.record_llm_call(tenant)

      updated = Tenants.get_tenant!(tenant.id)
      assert updated.llm_call_count == 2
    end
  end

  describe "BYOK cryptographic security and tamper detection" do
    test "encrypt_byok/1 and decrypt_byok/1 execute deterministic round-trip" do
      secret_api_key = "sk-ant-api03-test-token-roundtrip-verified-12345"
      encrypted = Tenants.encrypt_byok(secret_api_key)

      assert is_binary(encrypted)
      assert encrypted != secret_api_key

      assert {:ok, ^secret_api_key} = Tenants.decrypt_byok(encrypted)
    end

    test "tamper detection: corrupted ciphertext returns an error tuple instead of crashing" do
      secret_api_key = "sk-secret-payload-test"
      encrypted = Tenants.encrypt_byok(secret_api_key)

      # Corrupt ciphertext payload
      tampered = "corrupted" <> String.slice(encrypted, 9..-1//1)
      assert {:error, _reason} = Tenants.decrypt_byok(tampered)

      # Completely bogus string
      assert {:error, _reason} = Tenants.decrypt_byok("not_valid_ciphertext")
    end

    test "resolve_byok/1 handles unconfigured, configured, and corrupted states" do
      source = "byok_src_#{System.unique_integer([:positive])}"
      {:ok, tenant, _key} = Tenants.create_tenant("BYOK Corp", source)

      # 1. Unconfigured
      assert Tenants.resolve_byok(tenant) == :not_configured

      # 2. Configured with valid encrypted key
      secret_key = "sk-anthropic-live-test-override-key"
      encrypted = Tenants.encrypt_byok(secret_key)

      {:ok, byok_tenant} =
        tenant
        |> Tenant.byok_changeset(%{
          byok_provider: "anthropic",
          byok_api_key_encrypted: encrypted
        })
        |> SovereignSoulEngine.Repo.update()

      assert {:ok, AnthropicProvider, ^secret_key} = Tenants.resolve_byok(byok_tenant)

      # 3. Corrupted encrypted ciphertext gracefully fails with :decryption_failed
      {:ok, tampered_tenant} =
        byok_tenant
        |> Tenant.byok_changeset(%{
          byok_provider: "anthropic",
          byok_api_key_encrypted: "tampered_corrupted_key_payload"
        })
        |> SovereignSoulEngine.Repo.update()

      assert {:error, :decryption_failed} = Tenants.resolve_byok(tampered_tenant)

      # 4. clear_byok/1 resets back to unconfigured
      {:ok, cleared} = Tenants.clear_byok(tampered_tenant)
      assert Tenants.resolve_byok(cleared) == :not_configured
    end

    test "ProviderCascade respects tenant BYOK key precedence over operator cascade" do
      source = "prec_src_#{System.unique_integer([:positive])}"
      {:ok, tenant, _key} = Tenants.create_tenant("Precedence Corp", source)

      # Unconfigured tenant falls back to operator cascade (FakeProvider in test)
      assert {:ok, res} =
               ProviderCascade.respond(%{messages: [%{role: "user", content: "hi"}]},
                 tenant: tenant
               )

      assert is_map(res)

      # Configured tenant routes specifically to BYOK provider (even if it rejects dummy key)
      encrypted_bad_key = Tenants.encrypt_byok("invalid_key_for_test")

      {:ok, byok_tenant} =
        tenant
        |> Tenant.byok_changeset(%{
          byok_provider: "openai",
          byok_api_key_encrypted: encrypted_bad_key
        })
        |> SovereignSoulEngine.Repo.update()

      # BYOK route fails on provider check rather than silently falling back to operator cascade
      result =
        ProviderCascade.respond(%{messages: [%{role: "user", content: "hi"}]},
          tenant: byok_tenant
        )

      assert {:error, _reason} = result
    end
  end
end
