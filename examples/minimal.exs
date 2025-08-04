#!/usr/bin/env elixir

Mix.install([{:luagents, path: "."}])

agent = Luagents.create_agent(name: "MinimalBot")

IO.puts("🤖 Luagents Minimal Example\n")

task = "What is 15 + 27? Then multiply the result by 2. Show your reasoning."

IO.puts("Task: #{task}\n")

case Luagents.run_with_agent(agent, task) do
  {:ok, result} ->
    IO.puts("✅ Result: #{result}")

  {:error, "Ollama error: " <> _reason} ->
    IO.puts("""
    ❌ Ollama is not running. Quick setup:

    1. Install: brew install ollama
    2. Start: ollama serve
    3. Get model: ollama pull llama3.2
    """)

  {:error, error} ->
    IO.puts("❌ Error: #{error}")
end
