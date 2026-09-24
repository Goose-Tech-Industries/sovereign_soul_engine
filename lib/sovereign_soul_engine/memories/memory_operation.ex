defmodule SovereignSoulEngine.Memories.MemoryOperation do
  @moduledoc """
  Serializes memory mutations using character-scoped distributed locks.

  This follows Letta's memory-operation lease idea without moving SSE's
  canonical memory out of PostgreSQL. Reads remain concurrent; mutations for
  the same character are serialized so consolidation, purge, recall updates,
  and generation-side writes cannot race each other.
  """

  @doc """
  Runs a memory mutation while holding the owner character's lock.

  `nil` owners use the global memory lock. The lock key contains the binary
  identifier directly and never converts user input into an atom.
  """
  @spec with_owner(binary() | nil, (-> result)) :: result when result: var
  def with_owner(owner_id, fun) when is_function(fun, 0) do
    # Erlang's global lock identifier is {resource, requester}. Including the
    # caller process as requester is essential: using only the resource makes
    # concurrent callers look like the same re-entrant owner.
    lock_id = {{__MODULE__, lock_key(owner_id)}, self()}
    :global.trans(lock_id, fun)
  end

  @doc "Runs a mutation that cannot be safely scoped to one character."
  @spec with_global((-> result)) :: result when result: var
  def with_global(fun) when is_function(fun, 0) do
    with_owner(nil, fun)
  end

  defp lock_key(nil), do: :all
  defp lock_key(owner_id) when is_binary(owner_id), do: {:character, owner_id}
  defp lock_key(owner_id), do: {:character, inspect(owner_id)}
end
