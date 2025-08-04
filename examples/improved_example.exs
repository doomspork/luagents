#!/usr/bin/env elixir

Mix.install([
  {:luagents, path: "."},
  {:req, "~> 0.4"},
  {:jason, "~> 1.4"}
])

defmodule ExampleTools do
  @moduledoc """
  Custom tools for the Luagents example demonstrating various capabilities.
  """

  def create_web_search_tool() do
    Luagents.create_tool(
      "web_search",
      "Search the web using DuckDuckGo API (returns instant answers when available)",
      [
        %{name: "query", type: :string, description: "Search query", required: true}
      ],
      fn [query] ->
        search_duckduckgo(query)
      end
    )
  end

  def create_http_tool() do
    Luagents.create_tool(
      "http_get",
      "Make an HTTP GET request to a URL",
      [
        %{name: "url", type: :string, description: "URL to fetch", required: true}
      ],
      fn [url] ->
        make_http_request(url)
      end
    )
  end

  def create_json_parser_tool() do
    Luagents.create_tool(
      "parse_json",
      "Parse a JSON string and extract specific fields",
      [
        %{name: "json_string", type: :string, description: "JSON string to parse", required: true},
        %{name: "field", type: :string, description: "Field to extract (optional)", required: false}
      ],
      fn
        [json_string] -> parse_json(json_string, nil)
        [json_string, field] -> parse_json(json_string, field)
      end
    )
  end

  def create_word_counter_tool() do
    Luagents.create_tool(
      "count_words",
      "Count the number of words in a text",
      [
        %{name: "text", type: :string, description: "Text to count words in", required: true}
      ],
      fn [text] ->
        words = text |> String.split(~r/\s+/) |> Enum.filter(&(&1 != "")) |> length()
        {:ok, "The text contains #{words} words"}
      end
    )
  end

  defp search_duckduckgo(query) do
    url = "https://api.duckduckgo.com/"
    params = %{q: query, format: "json", no_redirect: "1"}

    case Req.get(url, params: params) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        result = extract_search_result(body)
        {:ok, result}

      {:ok, %{status: status}} ->
        {:error, "Search failed with status #{status}"}

      {:error, reason} ->
        {:error, "Search error: #{inspect(reason)}"}
    end
  rescue
    e -> {:error, "Exception during search: #{Exception.message(e)}"}
  end

  defp extract_search_result(data) do
    cond do
      abstract = data["Abstract"] || data["AbstractText"], abstract != "" ->
        source = data["AbstractSource"] || "Unknown"
        "#{abstract} (Source: #{source})"

      answer = data["Answer"], answer != "" ->
        type = data["AnswerType"] || "direct"
        "#{answer} (Answer type: #{type})"

      definition = data["Definition"], definition != "" ->
        source = data["DefinitionSource"] || "Unknown"
        "Definition: #{definition} (Source: #{source})"

      true ->
        related = data["RelatedTopics"] || []
        if length(related) > 0 do
          "Related topics found: #{length(related)} entries. First topic: #{inspect(hd(related)["Text"] || "N/A")}"
        else
          "No instant answer available. Try a more specific query or use a general web search."
        end
    end
  end

  defp make_http_request(url) do
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, format_response(body)}

      {:ok, %{status: status, body: body}} ->
        {:ok, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  rescue
    e -> {:error, "Exception during HTTP request: #{Exception.message(e)}"}
  end

  defp format_response(body) when is_binary(body), do: body
  defp format_response(body), do: Jason.encode!(body, pretty: true)

  defp parse_json(json_string, field) do
    case Jason.decode(json_string) do
      {:ok, data} ->
        if field do
          case get_in(data, String.split(field, ".")) do
            nil -> {:error, "Field '#{field}' not found in JSON"}
            value -> {:ok, "Field '#{field}': #{inspect(value)}"}
          end
        else
          {:ok, "Parsed JSON with keys: #{inspect(Map.keys(data))}"}
        end

      {:error, %Jason.DecodeError{} = error} ->
        {:error, "JSON parse error: #{Exception.message(error)}"}
    end
  rescue
    e -> {:error, "Exception during JSON parsing: #{Exception.message(e)}"}
  end
end

defmodule Examples do
  @moduledoc """
  Example scenarios demonstrating Luagents capabilities.
  """

  def run_all() do
    IO.puts("\n🤖 Luagents Advanced Examples")
    IO.puts("=" <> String.duplicate("=", 50))

    case check_ollama() do
      :ok ->
        run_examples()
      :error ->
        IO.puts("\n⚠️  Ollama is not running. Please start Ollama first:")
        IO.puts("   brew install ollama  # If not installed")
        IO.puts("   ollama serve        # Start the server")
        IO.puts("   ollama pull llama3.2 # Download the model")
    end
  end

  defp check_ollama() do
    case Req.get("http://localhost:11434/api/tags") do
      {:ok, %{status: 200}} -> :ok
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp run_examples() do
    example_simple_calculation()

    example_web_search()

    example_complex_task()

    example_error_handling()
  end

  defp example_simple_calculation() do
    IO.puts("\n📊 Example 1: Simple Calculation")
    IO.puts("-" <> String.duplicate("-", 30))

    agent = Luagents.create_agent(
      name: "Calculator",
      max_iterations: 5
    )

    task = "Calculate (5 + 3) * 2 using the add and multiply tools. Show your work."

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} -> IO.puts("✅ Result: #{result}")
      {:error, error} -> IO.puts("❌ Error: #{error}")
    end
  end

  defp example_web_search() do
    IO.puts("\n🔍 Example 2: Web Search")
    IO.puts("-" <> String.duplicate("-", 30))

    tools = Map.merge(
      Luagents.builtin_tools(),
      %{
        "web_search" => ExampleTools.create_web_search_tool(),
        "count_words" => ExampleTools.create_word_counter_tool()
      }
    )

    agent = Luagents.create_agent(
      name: "WebSearcher",
      tools: tools,
      max_iterations: 10
    )

    task = """
    Search for information about 'Elixir programming language' and then
    count how many words are in the search result.
    """

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} -> IO.puts("✅ Result: #{result}")
      {:error, error} -> IO.puts("❌ Error: #{error}")
    end
  end

  defp example_complex_task() do
    IO.puts("\n🔧 Example 3: Complex Multi-Step Task")
    IO.puts("-" <> String.duplicate("-", 30))

    tools = Map.merge(
      Luagents.builtin_tools(),
      %{
        "web_search" => ExampleTools.create_web_search_tool(),
        "http_get" => ExampleTools.create_http_tool(),
        "parse_json" => ExampleTools.create_json_parser_tool()
      }
    )

    agent = Luagents.create_agent(
      name: "DataAnalyzer",
      tools: tools,
      max_iterations: 15
    )

    task = """
    1. Make an HTTP GET request to https://httpbin.org/json
    2. Parse the JSON response and tell me what keys it contains
    3. Also search for 'JSON REST API' and summarize what you find
    """

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} -> IO.puts("✅ Result: #{result}")
      {:error, error} -> IO.puts("❌ Error: #{error}")
    end
  end

  defp example_error_handling() do
    IO.puts("\n⚡ Example 4: Error Handling")
    IO.puts("-" <> String.duplicate("-", 30))

    tools = Map.merge(
      Luagents.builtin_tools(),
      %{
        "failing_tool" => Luagents.create_tool(
          "failing_tool",
          "A tool that always fails (for testing error handling)",
          [],
          fn [] -> {:error, "This tool intentionally fails!"} end
        )
      }
    )

    agent = Luagents.create_agent(
      name: "ErrorHandler",
      tools: tools,
      max_iterations: 8
    )

    task = """
    Try to use the failing_tool, and when it fails, use the add tool
    to calculate 10 + 20 instead.
    """

    case Luagents.run_with_agent(agent, task) do
      {:ok, result} -> IO.puts("✅ Result: #{result}")
      {:error, error} -> IO.puts("❌ Error: #{error}")
    end
  end
end

# Run all examples
Examples.run_all()

IO.puts("\n✨ Examples completed!")
IO.puts("\nℹ️  Tips:")
IO.puts("- Ensure Ollama is running with a model like 'llama3.2'")
IO.puts("- Try modifying the tasks to see different behaviors")
IO.puts("- Add your own custom tools using Luagents.create_tool/4")
