defmodule SovereignSoulEngine.Memories.PurgeFilters do
  @moduledoc "Validates explicit deletion intent before any memory or knowledge is removed."

  def validate(opts, allowed \\ [:topic, :category]) do
    topic = Keyword.get(opts, :topic) || Keyword.get(opts, :query)
    category = Keyword.get(opts, :category)
    all = Keyword.get(opts, :all, false)

    cond do
      all not in [true, false] ->
        {:error, :invalid_purge_filters}

      not valid_text?(topic) or not valid_text?(category) ->
        {:error, :invalid_purge_filters}

      all ->
        {:ok, [all: true]}

      Enum.any?(allowed, fn key -> present?(if key == :topic, do: topic, else: category) end) ->
        {:ok, [topic: normalize(topic), category: normalize(category), all: false]}

      true ->
        {:error, :invalid_purge_filters}
    end
  end

  defp valid_text?(value), do: is_nil(value) or is_binary(value)
  defp present?(value), do: is_binary(value) and String.trim(value) != ""
  defp normalize(value), do: if(present?(value), do: String.trim(value))
end
