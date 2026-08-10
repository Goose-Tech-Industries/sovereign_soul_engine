defmodule SovereignSoulEngine.Souls.TraitCatalog do
  @moduledoc """
  Display metadata for `SoulProfile.personality_traits` — the underlying
  map keys (`"depression"`, `"bipolar"`, etc.) are unchanged; `generator.ex`
  reads those exact strings to build LLM prompts, so this module only adds
  a label + short behavioral blurb, never renames storage keys.

  Framed as behavior, not diagnosis: these drive how a character acts, not
  a clinical label attached to them, and the UI shouldn't present them as
  the latter. Single source of truth for every admin surface that lets
  someone toggle these (currently the NPC creation wizard; the vitals-tab
  edit form reuses this too).
  """

  @traits [
    %{
      key: "depression",
      label: "Emotionally Heavy",
      blurb: "Baseline mood runs low — joy and motivation take real effort to reach."
    },
    %{
      key: "bipolar",
      label: "Mood Swings",
      blurb: "Emotional baseline drifts between highs and lows over time, not just in reaction to events."
    },
    %{
      key: "ocd",
      label: "Compulsive Rituals",
      blurb: "Needs things done a specific way — deviation causes real, visible distress."
    },
    %{
      key: "splitting",
      label: "All-or-Nothing Views",
      blurb: "People and situations tend to flip between wholly good or wholly bad, little middle ground."
    },
    %{
      key: "adhd",
      label: "Restless Focus",
      blurb: "Attention jumps easily — sustained, single-track focus is a real strain."
    },
    %{
      key: "narcissism",
      label: "Self-Centered Worldview",
      blurb: "Own needs and image consistently outweigh others' in their internal calculus."
    },
    %{
      key: "impostor",
      label: "Impostor Doubt",
      blurb: "Achievements feel unearned — expects to be \"found out\" regardless of actual competence."
    },
    %{
      key: "codependency",
      label: "Loses Self in Others",
      blurb: "Own needs and identity blur into whoever they're closest to."
    },
    %{
      key: "addiction",
      label: "Compulsive Craving",
      blurb: "Something — substance, habit, person — pulls harder than judgment can resist."
    },
    %{
      key: "hypochondria",
      label: "Health Anxiety",
      blurb: "Reads ordinary sensations as signs of serious illness."
    }
  ]

  @doc "All traits, in a stable display order (unlike iterating the raw map)."
  def all, do: @traits

  def label(key), do: Enum.find_value(@traits, key, &(&1.key == key && &1.label))
  def blurb(key), do: Enum.find_value(@traits, "", &(&1.key == key && &1.blurb))

  @doc "The default all-false trait map, keyed exactly as SoulProfile.personality_traits expects."
  def default_map, do: Map.new(@traits, &{&1.key, false})
end
