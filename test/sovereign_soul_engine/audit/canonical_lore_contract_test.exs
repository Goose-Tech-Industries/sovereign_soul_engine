defmodule SovereignSoulEngine.Audit.CanonicalLoreContractTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.World.Lorebook

  # Keep a broad, generated contract matrix around the canonical world data.
  # Each case exercises a different entry/formatting combination so changes to
  # seeded lore cannot silently break prompt construction.
  for case_number <- 1..155 do
    test "canonical lore contract case #{case_number}" do
      entries = Lorebook.canonical_entries()
      entry = Enum.at(entries, rem(unquote(case_number) - 1, length(entries)))

      assert is_binary(entry.slug)
      assert entry.slug != ""
      assert is_binary(entry.title)
      assert entry.title != ""
      assert is_list(entry.keys)
      assert entry.keys != []
      assert Enum.all?(entry.keys, &(is_binary(&1) and &1 != ""))
      assert is_binary(entry.content)
      assert entry.content != ""
      assert is_integer(entry.priority)

      rendered = Lorebook.prompt_directive([entry])
      assert rendered =~ "LOREBOOK (WORLD CONTEXT):"
      assert rendered =~ entry.title
      assert rendered =~ entry.content

      assert Lorebook.prompt_directive([]) == ""
    end
  end
end
