defmodule Luagents.Memory do
  @moduledoc """
  Memory management for agent conversations.
  Stores the history of messages between user, assistant, and system.
  """

  defstruct messages: []

  @type message :: %{role: role, content: String.t(), timestamp: DateTime.t()}
  @type role :: :user | :assistant | :system
  @type t :: %__MODULE__{messages: [message]}

  def new do
    %__MODULE__{}
  end

  @spec add_message(t(), role(), String.t()) :: t()
  def add_message(%__MODULE__{messages: messages} = memory, role, content) do
    message = %{
      content: content,
      role: role,
      timestamp: DateTime.utc_now()
    }

    %{memory | messages: messages ++ [message]}
  end

  @spec get_messages(t()) :: [message()]
  def get_messages(%__MODULE__{messages: messages}), do: messages

  @spec format_messages(t()) :: String.t()
  def format_messages(%__MODULE__{messages: messages}) do
    Enum.map_join(messages, "\n", &format_message/1)
  end

  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = memory) do
    %{memory | messages: []}
  end

  @spec get_last_n_messages(t(), pos_integer()) :: [message()]
  def get_last_n_messages(%__MODULE__{messages: messages}, n) do
    Enum.take(messages, -n)
  end

  @spec to_chat_format(t()) :: [%{role: String.t(), content: String.t()}]
  def to_chat_format(%__MODULE__{messages: messages}) do
    Enum.map(messages, fn msg ->
      %{
        "role" => to_string(msg.role),
        "content" => msg.content
      }
    end)
  end

  defp format_message(%{role: role, content: content}) do
    role_str = role |> to_string() |> String.upcase()
    "#{role_str}: #{content}"
  end
end
