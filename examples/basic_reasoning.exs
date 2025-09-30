Mix.install([
  {:luagents, path: "."},
  {:ollama, "~> 0.8"},
  {:jason, "~> 1.4"},
  {:lua, "~> 0.3"}
])

defmodule WeatherTool do
  use Lua.API

  deflua get_weather(city) do
    weather = %{
      "London" => "{\"temperature\":55.0,\"weather\":\"Rainy\"}",
      "New York" => "{\"temperature\":72.0,\"weather\":\"Sunny\"}",
      "Tokyo" => "{\"temperature\":68.0,\"weather\":\"Cloudy\"}"
    }

    Map.get(weather, city)
  end

  deflua parse_json(json), state do
    data = Jason.decode!(json)
    Lua.encode!(state, data)
  end
end

tools = %{
  get_weather:
    Luagents.Tool.new(
      "get_weather",
      "Get's the weather for a city in a JSON format with temperature and weather keys",
      [%{name: "city", type: :string, description: "City name", required: true}],
      WeatherTool
    ),
  parse_json:
    Luagents.Tool.new(
      "parse_json",
      "Parse JSON",
      [%{name: "json", type: :string, description: "JSON string", required: true}],
      WeatherTool
    )
}

agent =
  Luagents.create_agent(
    llm: Luagents.LLM.new(),
    max_iterations: 10,
    name: "ReActDemo",
    tools: tools
  )

IO.puts("\n📍 Scenario 1: Basic Reasoning")
IO.puts("-" <> String.duplicate("-", 30))

task =
  "What's the weather like in New York and London? Compare them and tell me which city is warmer. Respond with the city name only."

IO.puts("Task: #{task}")

case Luagents.run_with_agent(agent, task) do
  {:ok, result} ->
    IO.puts("Result: #{result}")

    if result == "New York" do
      IO.puts("✅ Success!")
    else
      IO.puts("❌ Expected: New York, got: #{result}")
    end

  {:error, error} ->
    IO.puts("❌ Error: #{error}")
end

IO.puts("\n\n📍 Scenario 2: Error Recovery")
IO.puts("-" <> String.duplicate("-", 30))

agent = Luagents.reset_agent_memory(agent)

task = "Get the weather for Paris (which will fail), and when it fails, respond with temperature in Tokyo only."

IO.puts("Task: #{task}")

case Luagents.run_with_agent(agent, task) do
  {:ok, result} ->
    IO.puts("Result: #{result}")

    if result == 68.0 do
      IO.puts("✅ Success!")
    else
      IO.puts("❌ Expected: 68.0, got: #{result}")
    end

  {:error, error} ->
    IO.puts("❌ Error: #{error}")
end
