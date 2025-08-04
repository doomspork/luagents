#!/usr/bin/env elixir

Mix.install([
  {:luagents, path: "."},
  {:ollama, "0.8.0"}
])

defmodule ReactDemo do
  @moduledoc """
  Demonstrates the ReAct pattern with clear thought processes.
  """

  def run() do
    IO.puts("\n🧠 ReAct Pattern Demonstration")
    IO.puts("=" <> String.duplicate("=", 50))
    IO.puts("This shows how Luagents thinks step-by-step using Lua code.\n")

    tools = create_demo_tools()

    agent = Luagents.create_agent(
      name: "ReActDemo",
      tools: tools,
      max_iterations: 10
    )

    # Run different scenarios
    scenario_1_basic_reasoning(agent)
    scenario_2_error_recovery(agent)
    scenario_3_complex_reasoning(agent)
  end

  defp create_demo_tools() do
    Map.merge(
      Luagents.builtin_tools(),
      %{
        "get_weather" => Luagents.create_tool(
          "get_weather",
          "Get weather for a city (mock data)",
          [%{name: "city", type: :string, description: "City name", required: true}],
          fn [city] ->
            # Mock weather data
            weather = %{
              "New York" => "Sunny, 72°F",
              "London" => "Rainy, 55°F",
              "Tokyo" => "Cloudy, 68°F"
            }

            case Map.get(weather, city) do
              nil -> {:error, "Weather data not available for #{city}"}
              data -> {:ok, data}
            end
          end
        ),

        "calculate_trip_time" => Luagents.create_tool(
          "calculate_trip_time",
          "Calculate trip time between cities (mock data)",
          [
            %{name: "from", type: :string, description: "Starting city", required: true},
            %{name: "to", type: :string, description: "Destination city", required: true}
          ],
          fn [from, to] ->
            # Mock trip times in hours
            times = %{
              {"New York", "Boston"} => 4,
              {"Boston", "New York"} => 4,
              {"London", "Paris"} => 3,
              {"Paris", "London"} => 3
            }

            case Map.get(times, {from, to}) do
              nil -> {:error, "No route data available from #{from} to #{to}"}
              hours -> {:ok, "#{hours} hours"}
            end
          end
        ),

        "get_time" => Luagents.create_tool(
          "get_time",
          "Get current time in a timezone",
          [%{name: "timezone", type: :string, description: "Timezone (e.g., EST, UTC)", required: true}],
          fn [timezone] ->
            # Mock time data
            now = DateTime.utc_now()

            case timezone do
              "UTC" -> {:ok, "Current UTC time: #{DateTime.to_string(now)}"}
              "EST" ->
                est_time = DateTime.add(now, -5 * 3600, :second)
                {:ok, "Current EST time: #{DateTime.to_string(est_time)}"}
              _ -> {:error, "Unknown timezone: #{timezone}"}
            end
          end
        )
      }
    )
  end

  defp scenario_1_basic_reasoning(agent) do
    IO.puts("\n📍 Scenario 1: Basic Reasoning")
    IO.puts("-" <> String.duplicate("-", 30))

    task = """
    What's the weather like in New York and London?
    Compare them and tell me which city has better weather.
    """

    IO.puts("Task: #{task}\n")

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} ->
        IO.puts("✅ Success!")
        IO.puts("Agent's conclusion: #{result}")
      {:error, error} ->
        IO.puts("❌ Error: #{error}")
    end
  end

  defp scenario_2_error_recovery(agent) do
    IO.puts("\n\n📍 Scenario 2: Error Recovery")
    IO.puts("-" <> String.duplicate("-", 30))

    task = """
    Get the weather for Paris (which will fail), and when it fails,
    get the weather for Tokyo instead. Show how you handle the error.
    """

    IO.puts("Task: #{task}\n")

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} ->
        IO.puts("✅ Success!")
        IO.puts("Agent's conclusion: #{result}")
      {:error, error} ->
        IO.puts("❌ Error: #{error}")
    end
  end

  defp scenario_3_complex_reasoning(agent) do
    IO.puts("\n\n📍 Scenario 3: Complex Multi-Step Reasoning")
    IO.puts("-" <> String.duplicate("-", 30))

    task = """
    I need to travel from New York to Boston.
    1. Check the weather in both cities
    2. Calculate the trip time
    3. Get the current time in EST
    4. Tell me if it's a good time to travel based on the weather and time
    """

    IO.puts("Task: #{task}\n")

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} ->
        IO.puts("✅ Success!")
        IO.puts("Agent's conclusion: #{result}")
      {:error, error} ->
        IO.puts("❌ Error: #{error}")
    end
  end
end

# Check if Ollama is available
IO.puts("\n🔍 Checking Ollama availability...")

case Luagents.LLM.new(provider: :ollama) do
  ollama_llm when is_struct(ollama_llm) ->
    IO.puts("✅ Ollama is configured and ready!")
    ReactDemo.run()

  _ ->
    IO.puts("""
    ⚠️  Cannot connect to Ollama. Please ensure:

    1. Ollama is installed:
       brew install ollama

    2. Ollama service is running:
       ollama serve

    3. You have a model installed:
       ollama pull llama3.2

    Then run this example again.
    """)
end

IO.puts("\n✨ Demo completed!")
