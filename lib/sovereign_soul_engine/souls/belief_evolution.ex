defmodule SovereignSoulEngine.Souls.BeliefEvolution do
  @moduledoc """
  Epigenetic Belief Evolution: Dynamic adaptation of core values and beliefs under extreme emotional stress or profound bonding.

  Characters do not have immutable, static identities. Under traumatic betrayal (wound >= 80)
  or transcendent bonding (trust >= 90 with high affinity), baseline beliefs shift.
  """

  alias SovereignSoulEngine.Repo
  alias SovereignSoulEngine.Souls
  alias SovereignSoulEngine.Souls.SoulProfile
  alias SovereignSoulEngine.Ledger.LedgerBuilder

  require Logger

  @traumatic_shifts [
    {~r/protect the weak/i, "Only protect those who prove their loyalty"},
    {~r/loyalty must be earned/i, "Loyalty is a fragile transaction; betrayal is inevitable"},
    {~r/actions speak louder/i, "Watch their hands, never their words — promises are cheap"},
    {~r/strength is self-reliance/i, "Armor is meaningless if you let someone inside your guard"},
    {~r/trust/i, "Trust no one without collateral"},
    {~r/mercy/i, "Mercy given to a viper guarantees another bite"}
  ]

  @bonding_shifts [
    {~r/self-reliance/i, "True strength is forged through shared vulnerability"},
    {~r/fragile transaction/i, "Unconditional loyalty exists if you are brave enough to hold it"},
    {~r/guard/i, "Some bonds are worth lowering your shield for"},
    {~r/solitary|alone/i, "A shared burden makes the impossible possible"},
    {~r/trust no one/i, "Trust is a leap worth taking with those who have bled for you"}
  ]

  @doc """
  Evaluates whether a relationship state change triggers a belief shift in the character's SoulProfile.
  """
  def evaluate_shift(profile_or_id, relationship, opts \\ [])

  def evaluate_shift(%SoulProfile{} = profile, relationship, opts) do
    wound = Map.get(relationship, :wound, 0) || 0
    trust = Map.get(relationship, :trust, 0) || 0
    affinity = Map.get(relationship, :affinity, 0) || 0
    correlation_id = Keyword.get(opts, :correlation_id, Ecto.UUID.generate())

    cond do
      wound >= 80 ->
        trigger_traumatic_shift(profile, relationship, correlation_id)

      trust >= 90 and affinity >= 70 and wound < 20 ->
        trigger_bonding_shift(profile, relationship, correlation_id)

      true ->
        {:no_shift, "Thresholds for epigenetic belief shift not met"}
    end
  end

  def evaluate_shift(character_id, relationship, opts) when is_binary(character_id) do
    case Souls.get_soul_profile_by_character(character_id) do
      nil -> {:error, :profile_not_found}
      profile -> evaluate_shift(profile, relationship, opts)
    end
  end

  @doc """
  Applies a traumatic belief shift caused by severe betrayal or wound.
  """
  def trigger_traumatic_shift(%SoulProfile{} = profile, relationship, correlation_id) do
    current_values = profile.core_values || []

    {shifted_values, shifted_from, shifted_to} =
      evolve_values(current_values, @traumatic_shifts, :traumatic)

    reason =
      "Epigenetic betrayal shift: Severe wound (#{Map.get(relationship, :wound, 80)}/100) shattered baseline value."

    apply_evolution(
      profile,
      shifted_values,
      shifted_from,
      shifted_to,
      reason,
      :betrayal,
      correlation_id
    )
  end

  @doc """
  Applies a bonding belief shift caused by profound trust and high affinity.
  """
  def trigger_bonding_shift(%SoulProfile{} = profile, relationship, correlation_id) do
    current_values = profile.core_values || []

    {shifted_values, shifted_from, shifted_to} =
      evolve_values(current_values, @bonding_shifts, :bonding)

    reason =
      "Epigenetic bonding shift: Sustained transcendent trust (#{Map.get(relationship, :trust, 90)}/100) softened cynicism."

    apply_evolution(
      profile,
      shifted_values,
      shifted_from,
      shifted_to,
      reason,
      :bonding,
      correlation_id
    )
  end

  defp evolve_values(current_values, patterns, fallback_type) do
    match =
      Enum.find_value(current_values, fn val ->
        Enum.find_value(patterns, fn {regex, replacement} ->
          if Regex.match?(regex, val), do: {val, replacement}
        end)
      end)

    case match do
      {from_val, to_val} ->
        updated = Enum.map(current_values, fn v -> if v == from_val, do: to_val, else: v end)
        {updated, from_val, to_val}

      nil ->
        fallback_val =
          case fallback_type do
            :traumatic -> "Betrayal has proven that mercy without absolute strength is suicide"
            :bonding -> "True resolve is unlocked only when fighting for someone else"
          end

        {[fallback_val | current_values], "None (New Value)", fallback_val}
    end
  end

  defp apply_evolution(
         profile,
         new_values,
         shifted_from,
         shifted_to,
         reason,
         type,
         correlation_id
       ) do
    changeset =
      SoulProfile.changeset(profile, %{
        core_values: new_values,
        version: (profile.version || 1) + 1
      })

    case Repo.update(changeset) do
      {:ok, updated_profile} ->
        # Log to ledger
        commit_ledger_belief_entry(
          profile.character_id,
          shifted_from,
          shifted_to,
          reason,
          correlation_id
        )

        # Broadcast PubSub
        Phoenix.PubSub.broadcast(
          SovereignSoulEngine.PubSub,
          "character:#{profile.character_id}",
          {:belief_evolved,
           %{
             character_id: profile.character_id,
             type: type,
             from: shifted_from,
             to: shifted_to,
             reason: reason
           }}
        )

        {:ok,
         %{
           profile: updated_profile,
           shifted_from: shifted_from,
           shifted_to: shifted_to,
           reason: reason,
           type: type
         }}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp commit_ledger_belief_entry(character_id, from_val, to_val, reason, correlation_id) do
    entry =
      LedgerBuilder.build_event_entry(
        character_id: character_id,
        scene_id: nil,
        entry_type: :belief_evolved,
        source: "belief_evolution",
        label: "Epigenetic Belief Evolution",
        summary: "Core value shifted: '#{from_val}' -> '#{to_val}'",
        delta: %{
          before_value: from_val,
          after_value: to_val,
          reason: reason
        },
        correlation_id: correlation_id
      )

    Repo.insert(entry)
  rescue
    e ->
      Logger.warning("Could not write belief evolution ledger entry: #{inspect(e)}")
      :ok
  end
end
