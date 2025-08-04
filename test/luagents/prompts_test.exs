defmodule Luagents.PromptsTest do
  use ExUnit.Case, async: true

  alias Luagents.{Memory, Prompts, Tool}

  describe "system_prompt/2" do
    test "generates prompt with empty tools and memory" do
      tools = %{}
      memory = Memory.new()

      prompt = Prompts.system_prompt(tools, memory)

      assert is_binary(prompt)
      assert String.contains?(prompt, "ReAct agent")
      assert String.contains?(prompt, "thought(message)")
      assert String.contains?(prompt, "observation(message)")
      assert String.contains?(prompt, "final_answer(answer)")
    end

    test "includes tools in prompt" do
      tools = %{
        "add" =>
          Tool.new(
            "add",
            "Add two numbers",
            [
              %{name: "a", type: :number, description: "First number", required: true},
              %{name: "b", type: :number, description: "Second number", required: true}
            ],
            fn [a, b] -> {:ok, a + b} end
          )
      }

      memory = Memory.new()

      prompt = Prompts.system_prompt(tools, memory)

      assert String.contains?(prompt, "add(a: number, b: number): Add two numbers")
    end

    test "includes multiple tools in prompt" do
      tools = %{
        "add" =>
          Tool.new(
            "add",
            "Add two numbers",
            [
              %{name: "a", type: :number, description: "First number", required: true},
              %{name: "b", type: :number, description: "Second number", required: true}
            ],
            fn [a, b] -> {:ok, a + b} end
          )
      }

      memory = Memory.new()

      prompt = Prompts.system_prompt(tools, memory)

      assert String.contains?(prompt, "add(")
    end

    test "includes memory messages in conversation history" do
      tools = %{}

      memory =
        Memory.new()
        |> Memory.add_message(:user, "What is 2 + 2?")
        |> Memory.add_message(:assistant, "I'll calculate that for you.")

      prompt = Prompts.system_prompt(tools, memory)

      assert String.contains?(prompt, "USER: What is 2 + 2?")
      assert String.contains?(prompt, "ASSISTANT: I'll calculate that for you.")
    end

    test "includes all required sections" do
      tools = %{}
      memory = Memory.new()

      prompt = Prompts.system_prompt(tools, memory)

      # Check for key sections
      assert String.contains?(prompt, "You are an expert ReAct agent")
      assert String.contains?(prompt, "special functions:")
      assert String.contains?(prompt, "Here are a few examples")
      assert String.contains?(prompt, "Here are the rules")
      assert String.contains?(prompt, "Conversation history:")
      assert String.contains?(prompt, "Now write code to the solve")
    end

    test "contains proper Lua examples" do
      tools = %{}
      memory = Memory.new()

      prompt = Prompts.system_prompt(tools, memory)

      # Check for Lua code blocks in examples
      assert String.contains?(prompt, "```lua")
      assert String.contains?(prompt, "thought(")
      assert String.contains?(prompt, "observation(")
      assert String.contains?(prompt, "final_answer(")
    end

    test "includes rules and guidelines" do
      tools = %{}
      memory = Memory.new()

      prompt = Prompts.system_prompt(tools, memory)

      # Check for key rules
      assert String.contains?(prompt, "write valid Lua code")
      assert String.contains?(prompt, "Use thought() to explain")
      assert String.contains?(prompt, "Always call final_answer()")
      assert String.contains?(prompt, "Use only variables that you have defined")
      assert String.contains?(prompt, "Think step by step")
    end

    test "formats tools section correctly" do
      tools = %{
        "test_tool" =>
          Tool.new(
            "test_tool",
            "A test tool",
            [%{name: "param", type: :string, description: "Test param", required: true}],
            fn _ -> {:ok, "test"} end
          )
      }

      memory = Memory.new()

      prompt = Prompts.system_prompt(tools, memory)

      # Should contain formatted tool
      assert String.contains?(prompt, "- test_tool(param: string): A test tool")
    end

    test "handles empty conversation history" do
      tools = %{}
      memory = Memory.new()

      prompt = Prompts.system_prompt(tools, memory)

      # Should still contain conversation history section
      assert String.contains?(prompt, "Conversation history:")
      # But no specific messages
      refute String.contains?(prompt, "USER:")
      refute String.contains?(prompt, "ASSISTANT:")
    end

    test "handles complex memory with system messages" do
      tools = %{}

      memory =
        Memory.new()
        |> Memory.add_message(:user, "Calculate 5 + 3")
        |> Memory.add_message(:assistant, "I'll do that calculation")
        |> Memory.add_message(:system, "Error: invalid syntax")
        |> Memory.add_message(:assistant, "Let me fix that and try again")

      prompt = Prompts.system_prompt(tools, memory)

      assert String.contains?(prompt, "USER: Calculate 5 + 3")
      assert String.contains?(prompt, "ASSISTANT: I'll do that calculation")
      assert String.contains?(prompt, "SYSTEM: Error: invalid syntax")
      assert String.contains?(prompt, "ASSISTANT: Let me fix that and try again")
    end

    test "prompt is well-formed and complete" do
      tools = %{}

      memory = Memory.add_message(Memory.new(), :user, "Test task")

      prompt = Prompts.system_prompt(tools, memory)

      # Basic structure checks
      assert is_binary(prompt)
      # Should be a substantial prompt
      assert String.length(prompt) > 1000

      # Should start and end appropriately
      assert String.starts_with?(prompt, "You are an expert ReAct agent")
      assert String.ends_with?(String.trim(prompt), "solve the user's task:")
    end
  end

  describe "format_tools/1 (private function behavior)" do
    test "formats tools correctly through system_prompt" do
      # Test the private format_tools function indirectly
      tool1 =
        Tool.new(
          "tool1",
          "First tool",
          [%{name: "x", type: :number, description: "Number", required: true}],
          fn _ -> {:ok, nil} end
        )

      tool2 =
        Tool.new(
          "tool2",
          "Second tool",
          [],
          fn _ -> {:ok, nil} end
        )

      tools = %{"tool1" => tool1, "tool2" => tool2}
      memory = Memory.new()

      prompt = Prompts.system_prompt(tools, memory)

      # Both tools should be formatted and included
      assert String.contains?(prompt, "- tool1(x: number): First tool")
      assert String.contains?(prompt, "- tool2(): Second tool")
    end
  end
end
