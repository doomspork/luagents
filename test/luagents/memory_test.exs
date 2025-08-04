defmodule Luagents.MemoryTest do
  use ExUnit.Case, async: true

  alias Luagents.Memory

  describe "new/0" do
    test "creates empty memory" do
      memory = Memory.new()

      assert %Memory{messages: []} = memory
    end
  end

  describe "add_message/3" do
    test "adds message to empty memory" do
      memory = Memory.new()
      updated = Memory.add_message(memory, :user, "Hello")

      assert length(updated.messages) == 1
      message = hd(updated.messages)
      assert message.role == :user
      assert message.content == "Hello"
      assert %DateTime{} = message.timestamp
    end

    test "appends message to existing messages" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "First")
        |> Memory.add_message(:assistant, "Second")

      assert length(memory.messages) == 2
      [first, second] = memory.messages
      assert first.content == "First"
      assert second.content == "Second"
    end

    test "supports all role types" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "User message")
        |> Memory.add_message(:assistant, "Assistant message")
        |> Memory.add_message(:system, "System message")

      roles = Enum.map(memory.messages, & &1.role)
      assert roles == [:user, :assistant, :system]
    end

    test "adds timestamp to each message" do
      memory = Memory.new()
      before = DateTime.utc_now()
      updated = Memory.add_message(memory, :user, "Test")
      after_time = DateTime.utc_now()

      message = hd(updated.messages)
      assert DateTime.compare(message.timestamp, before) in [:gt, :eq]
      assert DateTime.compare(message.timestamp, after_time) in [:lt, :eq]
    end
  end

  describe "get_messages/1" do
    test "returns empty list for new memory" do
      memory = Memory.new()
      assert Memory.get_messages(memory) == []
    end

    test "returns all messages in order" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "First")
        |> Memory.add_message(:assistant, "Second")

      messages = Memory.get_messages(memory)
      assert length(messages) == 2
      assert Enum.map(messages, & &1.content) == ["First", "Second"]
    end
  end

  describe "format_messages/1" do
    test "formats empty memory as empty string" do
      memory = Memory.new()
      assert Memory.format_messages(memory) == ""
    end

    test "formats single message" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "Hello world")

      formatted = Memory.format_messages(memory)
      assert formatted == "USER: Hello world"
    end

    test "formats multiple messages with newlines" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "Question")
        |> Memory.add_message(:assistant, "Answer")
        |> Memory.add_message(:system, "Note")

      formatted = Memory.format_messages(memory)
      expected = "USER: Question\nASSISTANT: Answer\nSYSTEM: Note"
      assert formatted == expected
    end
  end

  describe "clear/1" do
    test "clears empty memory" do
      memory = Memory.new()
      cleared = Memory.clear(memory)

      assert cleared.messages == []
    end

    test "clears memory with messages" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "Message 1")
        |> Memory.add_message(:assistant, "Message 2")

      cleared = Memory.clear(memory)
      assert cleared.messages == []
    end
  end

  describe "get_last_n_messages/2" do
    test "returns empty list for empty memory" do
      memory = Memory.new()
      assert Memory.get_last_n_messages(memory, 3) == []
    end

    test "returns all messages when n is larger than message count" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "First")
        |> Memory.add_message(:assistant, "Second")

      messages = Memory.get_last_n_messages(memory, 5)
      assert length(messages) == 2
    end

    test "returns last n messages in order" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "First")
        |> Memory.add_message(:assistant, "Second")
        |> Memory.add_message(:system, "Third")
        |> Memory.add_message(:user, "Fourth")

      messages = Memory.get_last_n_messages(memory, 2)
      assert length(messages) == 2
      assert Enum.map(messages, & &1.content) == ["Third", "Fourth"]
    end

    test "returns single message when n is 1" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "First")
        |> Memory.add_message(:assistant, "Second")

      messages = Memory.get_last_n_messages(memory, 1)
      assert length(messages) == 1
      assert hd(messages).content == "Second"
    end
  end

  describe "to_chat_format/1" do
    test "converts empty memory to empty list" do
      memory = Memory.new()
      assert Memory.to_chat_format(memory) == []
    end

    test "converts messages to chat format" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "Hello")
        |> Memory.add_message(:assistant, "Hi there")
        |> Memory.add_message(:system, "System note")

      chat_format = Memory.to_chat_format(memory)

      expected = [
        %{"role" => "user", "content" => "Hello"},
        %{"role" => "assistant", "content" => "Hi there"},
        %{"role" => "system", "content" => "System note"}
      ]

      assert chat_format == expected
    end

    test "converts role atoms to strings" do
      memory =
        Memory.new()
        |> Memory.add_message(:user, "Test")

      [message] = Memory.to_chat_format(memory)
      assert message["role"] == "user"
      assert is_binary(message["role"])
    end
  end
end
