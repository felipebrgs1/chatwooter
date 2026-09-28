defmodule ChatwooterWeb.Components.Conversation.CardHelpers do
  @moduledoc "Data shared by the condensed and expanded conversation cards."

  # CardPriorityIcon.vue (Rails enum: low 0, medium 1, high 2, urgent 3); Phosphor instead of i-woot.
  @priorities %{
    0 => {"ph-cell-signal-low", "Low"},
    1 => {"ph-cell-signal-medium", "Medium"},
    2 => {"ph-cell-signal-high", "High"},
    3 => {"ph-cell-signal-full", "Urgent"}
  }

  @doc "`{icon, label}` of the priority, or nil."
  def priority(priority), do: @priorities[priority]

  @doc "chat.labels of the serializer = label_list, cached by acts_as_taggable_on as \"a, b\"."
  def labels(%{cached_label_list: list}) when is_binary(list),
    do: list |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

  def labels(_conversation), do: []

  @doc "getLastMessage (conversationHelper.js): the last non-activity message, else the last one."
  def last_message([]), do: nil

  def last_message(messages) do
    messages |> Enum.reject(&(&1.message_type == :activity)) |> List.last() || List.last(messages)
  end
end
