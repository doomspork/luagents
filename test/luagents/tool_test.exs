defmodule Luagents.ToolTest do
  use ExUnit.Case, async: true

  alias Luagents.Tool

  describe "new/4" do
    test "creates tool with all fields" do
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
  end

  describe "execute/2" do
    test "executes tool function with arguments" do
      tool =
        Tool.new(
          "add",
          "Add numbers",
          [],
          fn [a, b] -> {:ok, a + b} end
        )

      assert {:ok, 8} = Tool.execute(tool, [3, 5])
    end

    test "returns error result from function" do
      tool =
        Tool.new(
          "fail",
          "Always fails",
          [],
          fn _ -> {:error, "operation failed"} end
        )

      assert {:error, "operation failed"} = Tool.execute(tool, [])
    end

    test "catches and formats exceptions" do
      tool =
        Tool.new(
          "crash",
          "Raises exception",
          [],
          fn _ -> raise "boom" end
        )

      assert {:error, error_msg} = Tool.execute(tool, [])
      assert String.contains?(error_msg, "boom")
    end

    test "handles different argument types" do
      tool =
        Tool.new(
          "process",
          "Process mixed types",
          [],
          fn [str, num, bool] -> {:ok, "#{str}-#{num}-#{bool}"} end
        )

      assert {:ok, "hello-42-true"} = Tool.execute(tool, ["hello", 42, true])
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

  describe "builtin_tools/0" do
    test "returns map of built-in tools" do
      tools = Tool.builtin_tools()

      assert is_map(tools)
      assert Map.has_key?(tools, "add")
      assert Map.has_key?(tools, "multiply")
      assert Map.has_key?(tools, "concat")
      assert Map.has_key?(tools, "search")
    end

    test "add tool works correctly" do
      tools = Tool.builtin_tools()
      add_tool = Map.get(tools, "add")

      assert {:ok, 7} = Tool.execute(add_tool, [3, 4])
      assert {:ok, 0} = Tool.execute(add_tool, [-5, 5])
      assert {:ok, 10.5} = Tool.execute(add_tool, [2.5, 8])
    end

    test "multiply tool works correctly" do
      tools = Tool.builtin_tools()
      multiply_tool = Map.get(tools, "multiply")

      assert {:ok, 12} = Tool.execute(multiply_tool, [3, 4])
      assert {:ok, 0} = Tool.execute(multiply_tool, [0, 100])
      assert {:ok, -15} = Tool.execute(multiply_tool, [-3, 5])
    end

    test "concat tool works correctly" do
      tools = Tool.builtin_tools()
      concat_tool = Map.get(tools, "concat")

      assert {:ok, "hello world"} = Tool.execute(concat_tool, [["hello ", "world"]])
      assert {:ok, "abc"} = Tool.execute(concat_tool, [["a", "b", "c"]])
      assert {:ok, ""} = Tool.execute(concat_tool, [[]])
    end

    test "search tool returns mock results" do
      tools = Tool.builtin_tools()
      search_tool = Map.get(tools, "search")

      assert {:ok, result} = Tool.execute(search_tool, ["test query"])
      assert String.contains?(result, "test query")
      assert String.contains?(result, "Mock search results")
    end

    test "all built-in tools have proper structure" do
      tools = Tool.builtin_tools()

      for {name, tool} <- tools do
        assert %Tool{} = tool
        assert tool.name == name
        assert is_binary(tool.description)
        assert is_list(tool.parameters)
        assert is_function(tool.function)

        # Test that parameters have required fields
        for param <- tool.parameters do
          assert Map.has_key?(param, :name)
          assert Map.has_key?(param, :type)
          assert Map.has_key?(param, :description)
          assert Map.has_key?(param, :required)
        end
      end
    end

    test "built-in tools can be formatted for prompts" do
      tools = Tool.builtin_tools()

      for {_name, tool} <- tools do
        formatted = Tool.format_for_prompt(tool)
        assert is_binary(formatted)
        assert String.starts_with?(formatted, "- ")
        assert String.contains?(formatted, tool.name)
        assert String.contains?(formatted, tool.description)
      end
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
