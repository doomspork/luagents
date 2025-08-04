#!/usr/bin/env elixir

# Example demonstrating the multi-LLM support in Luagents
#
# This script shows how to create agents with different LLM providers
# and run the same task on both to compare results.
#
# Usage:
#   # Make sure you have:
#   # - ANTHROPIC_API_KEY environment variable set
#   # - Ollama running locally with a model like "llama3.2" available
#
#   elixir examples/multi_llm.exs

Mix.install([
  {:luagents, path: "."},
  {:anthropix, "~> 0.6"},
  {:ollama, "0.8.0"}
])

alias Luagents.{Agent, LLM, Tool}

# Define a simple calculator tool
calculator = Tool.new(
  name: "calculator",
  description: "Perform basic arithmetic operations",
  parameters: %{
    "operation" => %{"type" => "string", "description" => "The operation: add, subtract, multiply, divide"},
    "a" => %{"type" => "number", "description" => "First number"},
    "b" => %{"type" => "number", "description" => "Second number"}
  },
  function: fn %{"operation" => op, "a" => a, "b" => b} ->
    case op do
      "add" -> a + b
      "subtract" -> a - b
      "multiply" -> a * b
      "divide" when b != 0 -> a / b
      "divide" -> {:error, "Cannot divide by zero"}
      _ -> {:error, "Unknown operation: #{op}"}
    end
  end
)

# Create agents with different LLM providers
anthropic_agent = Agent.new(
  name: "AnthropicAgent",
  llm: LLM.new(provider: :anthropic),
  tools: %{"calculator" => calculator}
)

ollama_agent = Agent.new(
  name: "OllamaAgent",
  llm: LLM.new(provider: :ollama, model: "llama3.2"),
  tools: %{"calculator" => calculator}
)

# Test task
task = "Calculate the result of 15 * 8 + 23 and then divide by 7"

IO.puts("🧮 Multi-LLM Calculator Test")
IO.puts("Task: #{task}")
IO.puts(String.duplicate("=", 50))

# Run with Anthropic
IO.puts("\n🤖 Anthropic Claude Agent:")
case Agent.run(anthropic_agent, task) do
  {:ok, result} ->
    IO.puts("Result: #{result}")
  {:error, error} ->
    IO.puts("Error: #{error}")
end

# Run with Ollama
IO.puts("\n🦙 Ollama Agent:")
case Agent.run(ollama_agent, task) do
  {:ok, result} ->
    IO.puts("Result: #{result}")
  {:error, error} ->
    IO.puts("Error: #{error}")
end

IO.puts("\n✅ Test completed!")
IO.puts("\nNote: Make sure you have:")
IO.puts("- ANTHROPIC_API_KEY environment variable set")
IO.puts("- Ollama running locally with llama3.2 model available")
