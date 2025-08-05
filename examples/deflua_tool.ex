Mix.install([
  {:luagents, path: "."},
  {:ollama, "0.8.0"}
])

alias Luagents.Agent

defmodule PowerTool do
  use Lua.API

  deflua power(base, exp) do
    :math.pow(base, exp)
  end
end

tools = %{
  power:
    Luagents.Tool.new(
      "power",
      "Calculate power",
      [
        %{name: "base", type: :number, description: "Base", required: true},
        %{name: "exp", type: :number, description: "Exponent", required: true}
      ],
      PowerTool
    )
}

opts = [
  name: "MathBot",
  llm: Luagents.create_llm(:ollama, model: "llama3.1"),
  max_iterations: 15,
  tools: tools
]

agent = Luagents.create_agent(opts)
task = "What is 10 to the power of 2 raised to the power of 2?"

IO.puts("Task: #{task}")

case Agent.run(agent, task) do
  {:ok, result} ->
    IO.puts("Result: #{result}")

    if result == 10000.0 do
      IO.puts("✅ Success")
    else
      IO.puts("❌ Expected: 10000, got: #{result}")
    end

  {:error, error} ->
    IO.puts("❌ Error: #{error}")
end
