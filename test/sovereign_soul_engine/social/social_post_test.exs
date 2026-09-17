defmodule SovereignSoulEngine.Social.SocialPostTest do
  use ExUnit.Case, async: true

  alias SovereignSoulEngine.Social.SocialPost
  alias SovereignSoulEngine.Social.SocialFeed

  @char "11111111-1111-1111-1111-111111111111"

  defp valid_attrs do
    %{character_id: @char, content: "A short status update.", posted_at: DateTime.utc_now()}
  end

  describe "changeset/2" do
    test "is valid with required fields" do
      assert SocialPost.changeset(%SocialPost{}, valid_attrs()).valid?
    end

    test "requires content" do
      refute SocialPost.changeset(%SocialPost{}, Map.delete(valid_attrs(), :content)).valid?
    end

    test "requires a posted_at timestamp" do
      refute SocialPost.changeset(%SocialPost{}, Map.delete(valid_attrs(), :posted_at)).valid?
    end

    test "rejects content longer than 280 characters" do
      long = String.duplicate("a", 281)
      refute SocialPost.changeset(%SocialPost{}, %{valid_attrs() | content: long}).valid?
    end

    test "accepts exactly 280 characters" do
      exact = String.duplicate("a", 280)
      assert SocialPost.changeset(%SocialPost{}, %{valid_attrs() | content: exact}).valid?
    end
  end

  describe "SocialFeed.pubsub_topic/0" do
    test "exposes the feed topic" do
      assert SocialFeed.pubsub_topic() == "social:feed"
    end
  end
end
