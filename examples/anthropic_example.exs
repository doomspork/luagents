#!/usr/bin/env elixir

Mix.install([
  {:luagents, path: "."}
])

defmodule AnthropicExample do
  @moduledoc """
  Demonstrates using Luagents with Anthropic Claude LLM.
  """

  def run() do
    IO.puts("\n🤖 Luagents + Anthropic Claude Example")
    IO.puts("=" <> String.duplicate("=", 50))

    case System.get_env("ANTHROPIC_API_KEY") do
      nil ->
        print_setup_instructions()

      _api_key ->
        run_examples()
    end
  end

  defp run_examples() do
    IO.puts("✅ Found Anthropic API key, running examples...\n")

    simple_calculation_example()

    multi_step_reasoning_example()

    error_handling_example()
  end

  defp simple_calculation_example() do
    IO.puts("\n📊 Example 1: Simple Calculation with Claude")
    IO.puts("-" <> String.duplicate("-", 40))

    llm = Luagents.create_llm(:anthropic,
      model: "claude-3-5-sonnet-20241022",
      temperature: 0.1
    )

    agent = Luagents.create_agent(
      name: "ClaudeCalculator",
      llm: llm,
      max_iterations: 5
    )

    task = "Calculate (12 + 8) * 3 using the built-in tools. Show your step-by-step reasoning in Lua."

    IO.puts("Task: #{task}\n")

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} ->
        IO.puts("✅ Claude's Result: #{result}")

      {:error, error} ->
        IO.puts("❌ Error: #{error}")
    end
  end

  defp multi_step_reasoning_example() do
    IO.puts("\n\n🧠 Example 2: Multi-Step Reasoning")
    IO.puts("-" <> String.duplicate("-", 40))

    tools = Map.merge(
      Luagents.builtin_tools(),
      %{
        "analyze_string" => Luagents.create_tool(
          "analyze_string",
          "Analyze a string and return statistics",
          [%{name: "text", type: :string, description: "Text to analyze", required: true}],
          fn [text] ->
            chars = String.length(text)
            words = String.split(text, ~r/\s+/) |> length()
            vowels = Regex.scan(~r/[aeiouAEIOU]/, text) |> length()
            {:ok, "Characters: #{chars}, Words: #{words}, Vowels: #{vowels}"}
          end
        )
      }
    )

    llm = Luagents.create_llm(:anthropic,
      model: "claude-3-5-sonnet-20241022",
      temperature: 0.3
    )

    agent = Luagents.create_agent(
      name: "ClaudeAnalyst",
      llm: llm,
      tools: tools,
      max_iterations: 10
    )

    task = """
    Take the string "Hello Luagents World" and:
    1. Analyze it using the analyze_string tool
    2. Use the multiply tool to calculate how many characters would be in 5 copies
    3. Use the concat tool to join the original string with " - Powered by Claude"
    Show your reasoning at each step.
    """

    IO.puts("Task: #{String.trim(task)}\n")

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} ->
        IO.puts("✅ Claude's Analysis: #{result}")

      {:error, error} ->
        IO.puts("❌ Error: #{error}")
    end
  end

  defp error_handling_example() do
    IO.puts("\n\n⚡ Example 3: Error Handling")
    IO.puts("-" <> String.duplicate("-", 40))

    tools = Map.merge(
      Luagents.builtin_tools(),
      %{
        "unreliable_tool" => Luagents.create_tool(
          "unreliable_tool",
          "A tool that fails if input contains 'fail'",
          [%{name: "input", type: :string, description: "Input text", required: true}],
          fn [input] ->
            if String.contains?(input, "fail") do
              {:error, "Tool failed because input contains 'fail'"}
            else
              {:ok, "Success! Processed: #{input}"}
            end
          end
        )
      }
    )

    llm = Luagents.create_llm(:anthropic,
      model: "claude-3-5-sonnet-20241022",
      temperature: 0.5
    )

    agent = Luagents.create_agent(
      name: "ClaudeErrorHandler",
      llm: llm,
      tools: tools,
      max_iterations: 8
    )

    task = """
    Try to use the unreliable_tool with "test fail input" (which will fail),
    then when it fails, try again with "test success input" and
    use the add tool to calculate 10 + 5. Show how you handle the error.
    """

    IO.puts("Task: #{String.trim(task)}\n")

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} ->
        IO.puts("✅ Claude's Recovery: #{result}")

      {:error, error} ->
        IO.puts("❌ Error: #{error}")
    end
  end

  defp print_setup_instructions() do
    IO.puts("""
    ⚠️  Anthropic API key not found.

    To run this example, you need to set up your Anthropic API key:

    1. Get an API key from: https://console.anthropic.com/

    2. Set the environment variable:
       export ANTHROPIC_API_KEY="your-api-key-here"

    3. Or run with the key inline:
       ANTHROPIC_API_KEY="your-key" mix run examples/anthropic_example.exs

    4. Then run this example again.

    💡 You can also pass the API key directly in code:
       Luagents.create_llm(:anthropic, api_key: "your-key")
    """)
  end
end

AnthropicExample.run()
