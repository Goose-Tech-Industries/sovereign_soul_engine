defmodule SovereignSoulEngine.Actions do
  @moduledoc """
  Context for managing Action Intents — proposed, validated, and resolved actions.
  """

  alias SovereignSoulEngine.Actions.ActionIntent
  alias SovereignSoulEngine.Actions.ActionResolver
  alias SovereignSoulEngine.Cognition.Approvals
  alias SovereignSoulEngine.Cognition.ApprovalRequest
  alias SovereignSoulEngine.Repo

  import Ecto.Query

  def list_action_intents do
    Repo.all(ActionIntent)
  end

  def get_action_intent!(id), do: Repo.get!(ActionIntent, id)

  def list_action_intents_for_scene(scene_id) do
    Repo.all(
      from a in ActionIntent, where: a.scene_id == ^scene_id, order_by: [desc: :inserted_at]
    )
  end

  def list_action_intents_for_character(character_id) do
    Repo.all(
      from a in ActionIntent,
        where: a.character_id == ^character_id,
        order_by: [desc: :inserted_at]
    )
  end

  def list_pending_action_intents_for_character(character_id, action_types) do
    Repo.all(
      from a in ActionIntent,
        where:
          a.character_id == ^character_id and a.proposed_action in ^action_types and
            a.validation_status == "pending",
        order_by: [asc: :inserted_at]
    )
  end

  def create_action_intent(attrs \\ %{}) do
    %ActionIntent{}
    |> ActionIntent.changeset(attrs)
    |> Repo.insert()
  end

  def update_action_intent(%ActionIntent{} = intent, attrs) do
    intent
    |> ActionIntent.changeset(attrs)
    |> Repo.update()
  end

  def change_action_intent(%ActionIntent{} = intent, attrs \\ %{}) do
    ActionIntent.changeset(intent, attrs)
  end

  @doc "Resolves an action through deterministic policy and optionally creates an approval gate."
  def propose_action(attrs, policy_opts, opts \\ [])
      when is_map(attrs) and is_list(policy_opts) do
    with {:ok, intent} <- create_action_intent(attrs),
         {:ok, resolution} <- ActionResolver.resolve(policy_opts),
         {:ok, intent} <- persist_resolution(intent, resolution),
         {:ok, result} <- maybe_create_approval(intent, resolution, opts) do
      {:ok, result}
    end
  end

  @doc "Decides a pending approval and moves its linked action intent to a terminal policy state."
  def decide_approval(request_id, decision, attrs \\ %{}) do
    Repo.transaction(fn ->
      request = Repo.get!(ApprovalRequest, request_id)
      {:ok, decided} = Approvals.decide(request, decision, attrs)
      intent = Repo.get!(ActionIntent, decided.action_intent_id)

      consequences = intent.consequences || %{}

      status =
        if decision == "approved",
          do: Map.get(consequences, "policy_status", "approved"),
          else: "rejected"

      rejection_reason =
        if decision == "approved",
          do: nil,
          else: attrs[:decision_reason] || attrs["decision_reason"]

      {:ok, updated_intent} =
        update_action_intent(intent, %{
          validation_status: status,
          rejection_reason: rejection_reason,
          consequences: Map.put(intent.consequences || %{}, "approval_status", decision)
        })

      %{approval: decided, intent: updated_intent}
    end)
  end

  @doc "Runs an explicitly approved intent through a caller-owned executor and records the result."
  def execute_approved(request_id, executor) when is_function(executor, 1) do
    request = Repo.get!(ApprovalRequest, request_id)

    if request.status != "approved" do
      {:error, :approval_required}
    else
      intent = Repo.get!(ActionIntent, request.action_intent_id)

      case executor.(intent) do
        {:ok, result} ->
          {:ok, updated} =
            update_action_intent(intent, %{
              consequences:
                Map.merge(intent.consequences || %{}, %{
                  "execution_status" => "completed",
                  "execution_result" => result
                })
            })

          {:ok, updated}

        {:error, reason} ->
          {:ok, _updated} =
            update_action_intent(intent, %{
              consequences:
                Map.merge(intent.consequences || %{}, %{
                  "execution_status" => "failed",
                  "execution_error" => inspect(reason)
                })
            })

          {:error, reason}

        other ->
          {:error, {:invalid_executor_result, other}}
      end
    end
  end

  @doc "Records one idempotent external execution result from a game or device adapter."
  def record_external_execution(request_id, execution_key, status, result \\ %{})
      when is_binary(execution_key) and status in ["completed", "failed"] and is_map(result) do
    request = Repo.get!(ApprovalRequest, request_id)

    cond do
      request.status != "approved" ->
        {:error, :approval_required}

      request.execution_status == "completed" and request.execution_key != execution_key ->
        {:error, :already_executed}

      request.execution_key == execution_key and request.execution_status == status ->
        {:ok, request}

      true ->
        now = DateTime.utc_now()

        {:ok, updated_request} =
          request
          |> ApprovalRequest.changeset(%{
            execution_key: execution_key,
            execution_status: status,
            execution_result: result,
            executed_at: now
          })
          |> Repo.update()

        intent = Repo.get!(ActionIntent, request.action_intent_id)

        {:ok, _updated_intent} =
          update_action_intent(intent, %{
            consequences:
              Map.merge(intent.consequences || %{}, %{
                "execution_status" => status,
                "execution_key" => execution_key,
                "execution_result" => result
              })
          })

        {:ok, updated_request}
    end
  end

  defp persist_resolution(intent, resolution) do
    update_action_intent(intent, %{
      validation_status: Atom.to_string(resolution.validation_status),
      resolved_action: Atom.to_string(resolution.resolved_action),
      rejection_reason: resolution.rejection_reason,
      transformation_reason: resolution.transformation_reason,
      proposed_confidence: resolution.proposed_confidence,
      proposed_reason: resolution.proposed_reason
    })
  end

  defp maybe_create_approval(intent, resolution, opts) do
    requires_approval = Keyword.get(opts, :requires_approval, false)

    if requires_approval and resolution.validation_status in [:approved, :transformed] do
      policy_status = Atom.to_string(resolution.validation_status)

      with {:ok, request} <-
             Approvals.create(%{
               character_id: intent.character_id,
               action_intent_id: intent.id,
               operation: "action:#{resolution.resolved_action}",
               payload: %{resolved_action: Atom.to_string(resolution.resolved_action)},
               policy_context: %{reason: resolution.transformation_reason || "policy approved"},
               requested_by: Keyword.get(opts, :requested_by, "sse")
             }),
           {:ok, updated} <-
             update_action_intent(intent, %{
               validation_status: "pending",
               consequences: %{
                 "approval_required" => true,
                 "approval_request_id" => request.id,
                 "policy_status" => policy_status
               }
             }) do
        {:ok, %{intent: updated, approval: request}}
      end
    else
      {:ok, %{intent: intent, approval: nil}}
    end
  end
end
