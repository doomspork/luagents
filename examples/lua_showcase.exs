#!/usr/bin/env elixir

Mix.install([
  {:luagents, path: "."},
  {:ollama, "0.8.0"}
])

defmodule LuaShowcase do
  @moduledoc """
  Demonstrates the Lua code generation aspect of Luagents.
  """

  def run() do
    IO.puts("\n📜 Lua Code Generation Showcase")
    IO.puts("=" <> String.duplicate("=", 50))
    IO.puts("Watch how the agent writes Lua code to solve problems!\n")

    tools = create_showcase_tools()

    agent = Luagents.create_agent(
      name: "LuaCoder",
      tools: tools,
      max_iterations: 10
    )

    example_lua_tables(agent)

    example_lua_loops(agent)

    example_string_manipulation(agent)
  end

  defp create_showcase_tools() do
    Map.merge(
      Luagents.builtin_tools(),
      %{
        "create_table" => Luagents.create_tool(
          "create_table",
          "Create a Lua table from a list of items",
          [%{name: "items", type: :table, description: "List of items", required: true}],
          fn [items] when is_list(items) ->
            {:ok, "Created table with #{length(items)} items: #{inspect(items)}"}
          end
        ),

        "analyze_text" => Luagents.create_tool(
          "analyze_text",
          "Analyze text and return statistics",
          [%{name: "text", type: :string, description: "Text to analyze", required: true}],
          fn [text] ->
            words = String.split(text, ~r/\s+/) |> length()
            chars = String.length(text)
            {:ok, "Text stats: #{words} words, #{chars} characters"}
          end
        ),

        "fibonacci" => Luagents.create_tool(
          "fibonacci",
          "Calculate nth Fibonacci number",
          [%{name: "n", type: :number, description: "Position in sequence", required: true}],
          fn [n] when is_number(n) ->
            result = calculate_fib(round(n))
            {:ok, "Fibonacci(#{round(n)}) = #{result}"}
          end
        )
      }
    )
  end

  defp calculate_fib(n) when n <= 1, do: n
  defp calculate_fib(n), do: calculate_fib(n-1) + calculate_fib(n-2)

  defp example_lua_tables(agent) do
    IO.puts("\n🗂️  Example 1: Working with Lua Tables")
    IO.puts("-" <> String.duplicate("-", 35))

    task = """
    Create a Lua table with the numbers 1 through 5, then:
    1. Calculate the sum of all numbers
    2. Find the largest number
    3. Create a new table with each number doubled
    Show all your Lua code and explain what you're doing.
    """

    run_and_display(agent, task)
  end

  defp example_lua_loops(agent) do
    IO.puts("\n\n🔄 Example 2: Loops and Iterations")
    IO.puts("-" <> String.duplicate("-", 35))

    task = """
    Use the fibonacci tool to calculate the first 5 Fibonacci numbers.
    Store them in a Lua table and then calculate their sum.
    Use a for loop in your Lua code.
    """

    run_and_display(agent, task)
  end

  defp example_string_manipulation(agent) do
    IO.puts("\n\n📝 Example 3: String Manipulation")
    IO.puts("-" <> String.duplicate("-", 35))

    task = """
    Take the string "Hello Lua World" and:
    1. Convert it to uppercase
    2. Count the words using the analyze_text tool
    3. Reverse the string using Lua
    4. Concatenate it with " - Powered by Luagents"
    Show your Lua string manipulation code.
    """

    run_and_display(agent, task)
  end

  defp run_and_display(agent, task) do
    IO.puts("\nTask: #{String.trim(task)}\n")
    IO.puts("Generating Lua code...\n")

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} ->
        IO.puts("✅ Final Result: #{result}")

      {:error, error} ->
        IO.puts("❌ Error: #{error}")
    end
  end
end

case Luagents.LLM.new(provider: :ollama) do
  ollama_llm when is_struct(ollama_llm) ->
    LuaShowcase.run()
    IO.puts("\n💡 Notice how the agent:")
    IO.puts("   - Uses thought() to explain reasoning")
    IO.puts("   - Writes actual Lua code for computations")
    IO.puts("   - Uses observation() to note results")
    IO.puts("   - Calls final_answer() to provide the result")

  _ ->
    IO.puts("""
    ⚠️  Ollama is required for this example.

    Quick setup:
    1. brew install ollama
    2. ollama serve
    3. ollama pull llama3.2
    """)
end
