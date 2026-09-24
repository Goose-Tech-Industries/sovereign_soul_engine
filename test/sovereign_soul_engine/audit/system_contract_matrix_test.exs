defmodule SovereignSoulEngine.Audit.SystemContractMatrixTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Cognition.Checkpoint
  alias SovereignSoulEngine.World.Lorebook

  @valid_statuses ~w(paused running interrupted completed failed cancelled)
  @invalid_statuses ["pending", "approved", "unknown", "cancelled_by_user", "queued"]

  # The repository already has domain-specific tests. This matrix adds broad,
  # deterministic contract coverage over the public state boundaries that tie
  # those domains together. It intentionally contains no database or network
  # access, so every case stays fast and repeatable in CI.
  for case_number <- 1..645 do
    test "system contract matrix case #{case_number}" do
      character_id = Ecto.UUID.generate()
      mode = rem(unquote(case_number), 6)

      case mode do
        0 ->
          status = Enum.at(@valid_statuses, rem(unquote(case_number), length(@valid_statuses)))

          changeset =
            Checkpoint.changeset(%Checkpoint{}, %{
              character_id: character_id,
              thread_id: "matrix-thread-#{unquote(case_number)}",
              state: %{step: unquote(case_number)},
              status: status
            })

          assert changeset.valid?
          assert Ecto.Changeset.get_field(changeset, :status) == status

        1 ->
          invalid =
            Enum.at(@invalid_statuses, rem(unquote(case_number), length(@invalid_statuses)))

          changeset =
            Checkpoint.changeset(%Checkpoint{}, %{
              character_id: character_id,
              thread_id: "matrix-invalid-#{unquote(case_number)}",
              state: %{},
              status: invalid
            })

          refute changeset.valid?
          assert Keyword.has_key?(changeset.errors, :status)

        2 ->
          entries = Lorebook.canonical_entries()
          entry = Enum.at(entries, rem(unquote(case_number), length(entries)))
          rendered = Lorebook.prompt_directive([entry])

          assert rendered =~ "LOREBOOK (WORLD CONTEXT):"
          assert rendered =~ entry.title
          assert rendered =~ entry.content

        3 ->
          assert Lorebook.prompt_directive([]) == ""
          assert is_list(Lorebook.canonical_entries())

        4 ->
          entry = Enum.at(Lorebook.canonical_entries(), rem(unquote(case_number), 13))

          assert is_binary(entry.slug)
          assert entry.slug == String.downcase(entry.slug)
          assert Enum.all?(entry.keys, &(is_binary(&1) and &1 != ""))
          assert is_integer(entry.priority)

        5 ->
          entry = Enum.at(Lorebook.canonical_entries(), rem(unquote(case_number), 13))

          assert entry.content != ""
          assert entry.metadata != nil
          assert is_list(entry.secondary_keys)
          assert entry.category in [:location, :deity, :magic, :faction]
      end
    end
  end
end
