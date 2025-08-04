Mix.install([
  {:luagents, path: "."},
  {:ollama, "0.8.0"}
])

alias Luagents.Agent

# Create custom tools
power_tool = Luagents.create_tool(
  "power",
  "Calculate power",
  [
    %{name: "base", type: :number, description: "Base", required: true},
    %{name: "exp", type: :number, description: "Exponent", required: true}
  ],
  fn [base, exp] -> {:ok, :math.pow(base, exp)} end
)

# Add to existing tools
tools = Map.put(Luagents.builtin_tools(), "power", power_tool)
opts = [
  name: "MathBot",
  llm: Luagents.create_llm(:ollama, model: "llama3.1"),
  max_iterations: 15,
  tools: tools
]

agent = Luagents.create_agent(opts)

case Agent.run(agent, "What is 10 to the power of 2 raised to the power of 2?") do
  {:ok, result} -> IO.puts("Result: #{result}")
  {:error, error} -> IO.puts("Error: #{error}")
end

# Agent introspection
info = Luagents.get_agent_info(agent)
memory = Luagents.get_agent_memory(agent)

dbg(info)
dbg(memory)
