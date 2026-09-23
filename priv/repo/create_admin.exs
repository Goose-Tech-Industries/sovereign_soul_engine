# priv/repo/create_admin.exs
alias SovereignSoulEngine.{Repo, Characters}
alias SovereignSoulEngine.Accounts.User

email = System.get_env("SSE_ADMIN_EMAIL", "admin@sovereignsoul.ai")
password = System.fetch_env!("SSE_ADMIN_PASSWORD")

user = Repo.get_by(User, email: email)

user =
  if user do
    user
    |> Ecto.Changeset.change(%{
      hashed_password: Pbkdf2.hash_pwd_salt(password),
      confirmed_at: DateTime.utc_now(:second),
      subscription_tier: "archon_1999",
      opt_out_living_world: false
    })
    |> Repo.update!()
  else
    %User{}
    |> Ecto.Changeset.change(%{
      email: email,
      hashed_password: Pbkdf2.hash_pwd_salt(password),
      confirmed_at: DateTime.utc_now(:second),
      subscription_tier: "archon_1999",
      opt_out_living_world: false
    })
    |> Repo.insert!()
  end

player = Characters.get_or_create_player_for_user(user)

IO.puts("==================================================")
IO.puts("Admin Profile Initialized Successfully!")
IO.puts("User ID: #{user.id}")
IO.puts("Email: #{user.email}")
IO.puts("Grant ACP access by adding this user ID to SSE_ADMIN_USER_IDS and restarting the app.")
IO.puts("Subscription Tier: #{user.subscription_tier}")
IO.puts("Confirmed: #{not is_nil(user.confirmed_at)}")
IO.puts("Opt-out Living World: #{user.opt_out_living_world}")
IO.puts("Primary Player Character: #{player.name} (ID: #{player.id})")
IO.puts("==================================================")
