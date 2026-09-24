defmodule SovereignSoulEngine.SoulEventsTest do
  use SovereignSoulEngine.DataCase

  alias SovereignSoulEngine.SoulEvents
  alias SovereignSoulEngine.Scenes.SoulEvent

  test "creates and lists canonical events" do
    occurred_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    assert {:ok, %SoulEvent{} = event} =
             SoulEvents.create_event(%{
               event_type: "praised_me",
               intensity: 80,
               occurred_at: occurred_at
             })

    assert event.event_type == "praised_me"
    assert [listed] = SoulEvents.list_events()
    assert listed.id == event.id
    assert SoulEvents.get_event!(event.id).id == event.id
  end

  test "filters events by scene and target character" do
    assert SoulEvents.list_events_for_scene(Ecto.UUID.generate()) == []
    assert SoulEvents.list_events_for_character(Ecto.UUID.generate()) == []
  end

  test "changesets validate event type, timestamp, and intensity" do
    assert {:error, changeset} = SoulEvents.create_event(%{occurred_at: DateTime.utc_now()})
    assert %{event_type: ["can't be blank"]} = errors_on(changeset)

    event = %SoulEvent{}

    changeset =
      SoulEvents.change_event(event, %{
        event_type: "invalid",
        occurred_at: DateTime.utc_now(),
        intensity: 101
      })

    errors = errors_on(changeset)
    assert errors.event_type == ["is invalid"]
    assert errors.intensity == ["must be less than or equal to 100"]
  end
end
