defmodule SovereignSoulEngine.Repo.Migrations.AddSocialStaminaToSoulProfiles do
  use Ecto.Migration

  def change do
    alter table(:soul_profiles) do
      # Current social energy. Conversations drain it; scheduler ticks regenerate it.
      # Avoidant attachment drains faster; anxious drains on abandonment/conflict.
      add :social_stamina, :integer, default: 80
      # How fast stamina regenerates per scheduler tick (regen_rate units per tick)
      add :stamina_regen_rate, :integer, default: 10
      # Maximum stamina ceiling (introverts may cap lower)
      add :stamina_max, :integer, default: 100
      # Timestamp of last autonomous social action (conversation initiation or drift update)
      add :last_social_action_at, :utc_datetime
    end
  end
end
