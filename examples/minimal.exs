Mix.install([
  {:luagents, path: "."},
  {:ollama, "0.8.0"}
])

agent = Luagents.create_agent(name: "MinimalBot")

task = "What is 15 + 27? Then multiply the result by 2."

IO.puts("Task: #{task}")

case Luagents.run_with_agent(agent, task) do
  {:ok, result} ->
    IO.puts("Result: #{result}")

    if result == 84 do
      IO.puts("✅ Success")
    else
      IO.puts("❌ Expected: 84.0")
    end

  {:error, error} ->
    IO.puts("❌ Error: #{error}")
end
