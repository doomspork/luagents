defmodule Luagents.ToolTest do
  use ExUnit.Case, async: true

  alias Luagents.Tool

  describe "new/4" do
    test "creates tool from function with all fields" do
      parameters = [
        %{name: "x", type: :number, description: "Input number", required: true}
      ]

      function = fn [x] -> {:ok, x * 2} end

      tool = Tool.new("double", "Double a number", parameters, function)

      assert tool.name == "double"
      assert tool.description == "Double a number"
      assert tool.parameters == parameters
      assert tool.function == function
    end

    test "creates tool from deflua module with all fields" do
      defmodule WebSearch do
        use Lua.API

        deflua search(query) do
          "Searching for #{query}"
        end
      end

      tool =
        Tool.new(
          "search",
          "Search the web",
          [%{name: "query", type: :string, description: "Search query", required: true}],
          WebSearch
        )

      assert tool.name == "search"
      assert tool.description == "Search the web"
      assert tool.parameters == [%{name: "query", type: :string, description: "Search query", required: true}]
      assert tool.api == WebSearch
    end
  end

  describe "format_for_prompt/1" do
    test "formats tool with simple parameters" do
      parameters = [
        %{name: "a", type: :number, description: "First number", required: true},
        %{name: "b", type: :number, description: "Second number", required: true}
      ]

      tool = Tool.new("add", "Add two numbers", parameters, fn _ -> {:ok, nil} end)
      formatted = Tool.format_for_prompt(tool)

      expected = "- add(a: number, b: number): Add two numbers\n"
      assert formatted == expected
    end

    test "formats tool with optional parameters" do
      parameters = [
        %{name: "text", type: :string, description: "Input text", required: true},
        %{name: "times", type: :number, description: "Repeat count", required: false}
      ]

      tool = Tool.new("repeat", "Repeat text", parameters, fn _ -> {:ok, nil} end)
      formatted = Tool.format_for_prompt(tool)

      expected = "- repeat(text: string, times?: number): Repeat text\n"
      assert formatted == expected
    end

    test "formats tool with no parameters" do
      tool = Tool.new("current_time", "Get current time", [], fn _ -> {:ok, nil} end)
      formatted = Tool.format_for_prompt(tool)

      expected = "- current_time(): Get current time\n"
      assert formatted == expected
    end

    test "formats tool with table parameter" do
      parameters = [
        %{name: "items", type: :table, description: "List of items", required: true}
      ]

      tool = Tool.new("process_list", "Process items", parameters, fn _ -> {:ok, nil} end)
      formatted = Tool.format_for_prompt(tool)

      expected = "- process_list(items: table): Process items\n"
      assert formatted == expected
    end
  end

  describe "parameter formatting edge cases" do
    test "handles mixed required and optional parameters" do
      parameters = [
        %{name: "required1", type: :string, description: "Required param", required: true},
        %{name: "optional1", type: :number, description: "Optional param", required: false},
        %{name: "required2", type: :boolean, description: "Another required", required: true}
      ]

      tool = Tool.new("mixed", "Mixed parameters", parameters, fn _ -> {:ok, nil} end)
      formatted = Tool.format_for_prompt(tool)

      assert String.contains?(formatted, "required1: string")
      assert String.contains?(formatted, "optional1?: number")
      assert String.contains?(formatted, "required2: boolean")
    end

    test "handles all parameter types" do
      parameters = [
        %{name: "str", type: :string, description: "String param", required: true},
        %{name: "num", type: :number, description: "Number param", required: true},
        %{name: "bool", type: :boolean, description: "Boolean param", required: true},
        %{name: "tbl", type: :table, description: "Table param", required: true}
      ]

      tool = Tool.new("types", "All types", parameters, fn _ -> {:ok, nil} end)
      formatted = Tool.format_for_prompt(tool)

      assert String.contains?(formatted, "str: string")
      assert String.contains?(formatted, "num: number")
      assert String.contains?(formatted, "bool: boolean")
      assert String.contains?(formatted, "tbl: table")
    end
  end
end
