defmodule Luagents.ToolTest do
  use ExUnit.Case, async: true

  alias Luagents.Tool

  describe "new/4" do
    test "creates tool from function with all fields" do
      parameters = [
        %{name: "x", type: :number, description: "Input number", required: true}
      ]

      function = fn [x] -> x * 2 end

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

      tool = Tool.new("add", "Add two numbers", parameters, fn _ -> nil end)
      formatted = Tool.format_for_prompt(tool)

      expected = "- add(a: number, b: number): Add two numbers\n"
      assert formatted == expected
    end

    test "formats tool with optional parameters" do
      parameters = [
        %{name: "text", type: :string, description: "Input text", required: true},
        %{name: "times", type: :number, description: "Repeat count", required: false}
      ]

      tool = Tool.new("repeat", "Repeat text", parameters, fn _ -> nil end)
      formatted = Tool.format_for_prompt(tool)

      expected = "- repeat(text: string, times?: number): Repeat text\n"
      assert formatted == expected
    end

    test "formats tool with no parameters" do
      tool = Tool.new("current_time", "Get current time", [], fn _ -> nil end)
      formatted = Tool.format_for_prompt(tool)

      expected = "- current_time(): Get current time\n"
      assert formatted == expected
    end

    test "formats tool with table parameter" do
      parameters = [
        %{name: "items", type: :table, description: "List of items", required: true}
      ]

      tool = Tool.new("process_list", "Process items", parameters, fn _ -> nil end)
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

      tool = Tool.new("mixed", "Mixed parameters", parameters, fn _ -> nil end)
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

      tool = Tool.new("types", "All types", parameters, fn _ -> nil end)
      formatted = Tool.format_for_prompt(tool)

      assert String.contains?(formatted, "str: string")
      assert String.contains?(formatted, "num: number")
      assert String.contains?(formatted, "bool: boolean")
      assert String.contains?(formatted, "tbl: table")
    end
  end

  describe "from_module/2" do
    test "extracts all public functions from module" do
      tools = Tool.from_module(Luagents.Tools.Json)

      assert map_size(tools) == 3
      assert Map.has_key?(tools, :parse)
      assert Map.has_key?(tools, :encode)
      assert Map.has_key?(tools, :pretty)
    end

    test "creates tools with correct names using scope" do
      tools = Tool.from_module(Luagents.Tools.Json)

      assert tools.parse.name == "json.parse"
      assert tools.encode.name == "json.encode"
      assert tools.pretty.name == "json.pretty"
    end

    test "extracts descriptions from @doc" do
      tools = Tool.from_module(Luagents.Tools.Json)

      assert tools.parse.description == "Parse a JSON string into a Lua table."
      assert tools.encode.description == "Encode a Lua table/value into a JSON string."
      assert tools.pretty.description == "Pretty-print encode a Lua table/value into a formatted JSON string."
    end

    test "extracts parameter names from signatures" do
      tools = Tool.from_module(Luagents.Tools.Json)

      # JSON tools have deflua state parameter which is automatically filtered out
      assert length(tools.parse.parameters) == 1
      assert hd(tools.parse.parameters).name == "json_string"
      assert hd(tools.parse.parameters).required == true

      assert length(tools.encode.parameters) == 1
      assert hd(tools.encode.parameters).name == "data"
      assert hd(tools.encode.parameters).required == true

      logger_tools = Tool.from_module(Luagents.Tools.Logger)
      log_params = logger_tools.log.parameters

      assert length(log_params) >= 2
      [first, second | _] = log_params
      assert first.name == "level"
      assert first.required == true
      assert second.name == "message"
      assert second.required == true
    end

    test "sets api field to module" do
      tools = Tool.from_module(Luagents.Tools.Json)

      assert tools.parse.api == Luagents.Tools.Json
      assert tools.encode.api == Luagents.Tools.Json
      assert tools.pretty.api == Luagents.Tools.Json
    end

    test "uses module's scope for tool names" do
      tools = Tool.from_module(Luagents.Tools.Json)

      assert tools.parse.name == "json.parse"
      assert tools.encode.name == "json.encode"
      assert tools.pretty.name == "json.pretty"
    end

    test "applies only option" do
      tools = Tool.from_module(Luagents.Tools.Json, only: [:parse, :encode])

      assert map_size(tools) == 2
      assert Map.has_key?(tools, :parse)
      assert Map.has_key?(tools, :encode)
      refute Map.has_key?(tools, :pretty)
    end

    test "applies except option" do
      tools = Tool.from_module(Luagents.Tools.Json, except: [:pretty])

      assert map_size(tools) == 2
      assert Map.has_key?(tools, :parse)
      assert Map.has_key?(tools, :encode)
      refute Map.has_key?(tools, :pretty)
    end

    test "applies param_types option" do
      tools = Tool.from_module(Luagents.Tools.Json, param_types: %{data: :table, json_string: :string})

      assert hd(tools.parse.parameters).type == :string
      assert hd(tools.encode.parameters).type == :table
    end

    test "defaults parameter types appropriately" do
      tools = Tool.from_module(Luagents.Tools.Json)

      assert hd(tools.parse.parameters).type == :string
      assert hd(tools.encode.parameters).type == :table
    end
  end

  describe "from_function/3" do
    test "extracts single function from module using scope" do
      tool = Tool.from_function(Luagents.Tools.Json, :parse)

      assert tool.name == "json.parse"
      assert tool.description == "Parse a JSON string into a Lua table."
      assert tool.api == Luagents.Tools.Json
    end

    test "applies as option for custom name" do
      tool = Tool.from_function(Luagents.Tools.Json, :parse, as: "json_parse")

      assert tool.name == "json_parse"
    end

    test "applies param_types option" do
      tool =
        Tool.from_function(Luagents.Tools.Json, :encode, param_types: %{data: :table})

      assert hd(tool.parameters).type == :table
    end

    test "raises error for non-existent function" do
      assert_raise ArgumentError, ~r/Function nonexistent not found/, fn ->
        Tool.from_function(Luagents.Tools.Json, :nonexistent)
      end
    end

    test "handles multiple optional parameters" do
      tool = Tool.from_function(Luagents.Tools.Logger, :log)

      assert length(tool.parameters) >= 2
      [a, b | _rest] = tool.parameters

      assert a.name == "level"
      assert a.required == true

      assert b.name == "message"
      assert b.required == true

      if length(tool.parameters) >= 3 do
        c = Enum.at(tool.parameters, 2)
        assert c.name == "metadata"
        assert c.required == false
      end
    end
  end

  describe "@doc parameter descriptions" do
    test "extracts parameter descriptions from ## Parameters section" do
      tools = Tool.from_module(Luagents.Tools.Http)

      get_params = tools.get.parameters
      assert length(get_params) >= 2

      url_param = Enum.find(get_params, &(&1.name == "url"))
      assert url_param != nil
      assert url_param.description == "The URL to request"
    end

    test "extracts parameter descriptions from ## Parameters with all fields" do
      tools = Tool.from_module(Luagents.Tools.Http)

      post_params = tools.post.parameters

      assert length(post_params) >= 3

      url_param = Enum.find(post_params, &(&1.name == "url"))
      body_param = Enum.find(post_params, &(&1.name == "body"))
      headers_param = Enum.find(post_params, &(&1.name == "headers"))

      assert url_param.description == "The URL to request"
      assert body_param.description == "The request body (string or table)"
      assert headers_param.description == "Optional table of headers (default: {})"
    end

    test "handles functions without ## Parameters section gracefully" do
      tools = Tool.from_module(Luagents.Tools.Logger)

      debug_params = tools.debug.parameters
      assert length(debug_params) >= 1
      message_param = hd(debug_params)
      assert message_param.name == "message"
    end
  end

  describe "[type] annotations in @doc" do
    test "extracts types from [type] annotations" do
      tool = Tool.from_function(Luagents.Test.TypeAnnotationTools, :process)

      assert length(tool.parameters) == 4
      [name, count, enabled, data] = tool.parameters

      assert name.name == "name"
      assert name.type == :string
      assert name.description == "The name value"

      assert count.name == "count"
      assert count.type == :number
      assert count.description == "The count value"

      assert enabled.name == "enabled"
      assert enabled.type == :boolean
      assert enabled.description == "Whether enabled"

      assert data.name == "data"
      assert data.type == :table
      assert data.description == "The data structure"
    end

    test "extracts types from (type) annotations" do
      tool = Tool.from_function(Luagents.Test.TypeAnnotationTools, :test_parens)

      assert length(tool.parameters) == 2
      [value, items] = tool.parameters

      assert value.name == "value"
      assert value.type == :number
      assert value.description == "A numeric value"

      assert items.name == "items"
      assert items.type == :table
      assert items.description == "A list of items"
    end

    test "supports alternative type names (list, array, map)" do
      tool = Tool.from_function(Luagents.Test.AltTypeTools, :test_alt)

      [items, arr, obj] = tool.parameters

      assert items.type == :table
      assert arr.type == :table
      assert obj.type == :table
    end
  end

  describe "@spec type extraction" do
    test "extracts types from @spec for integer" do
      tool = Tool.from_function(Luagents.Test.SpecTools, :add)

      assert length(tool.parameters) == 2
      [a, b] = tool.parameters

      assert a.type == :number
      assert b.type == :number
    end

    test "extracts types from @spec for String.t()" do
      tool = Tool.from_function(Luagents.Test.SpecTools, :concat)

      assert length(tool.parameters) == 2
      [s1, s2] = tool.parameters

      assert s1.type == :string
      assert s2.type == :string
    end

    test "extracts types from @spec for boolean" do
      tool = Tool.from_function(Luagents.Test.SpecTools, :equal?)

      assert length(tool.parameters) == 2
    end

    test "extracts types from @spec for list" do
      tool = Tool.from_function(Luagents.Test.SpecTools, :process_list)

      assert length(tool.parameters) == 1
      [items] = tool.parameters

      assert items.type == :table
    end
  end

  describe "priority order" do
    test "param_types option overrides everything" do
      tool =
        Tool.from_function(Luagents.Test.PriorityTools, :test_priority,
          param_types: %{param1: :string, param2: :boolean}
        )

      [p1, p2] = tool.parameters

      assert p1.type == :string
      assert p2.type == :boolean
    end

    test "@doc annotation takes precedence over @spec" do
      tool = Tool.from_function(Luagents.Test.PriorityTools, :test_priority)

      [p1, p2] = tool.parameters

      assert p1.type == :number

      assert p2.type == :string
    end

    test "defaults to :string when no type info available" do
      tool = Tool.from_function(Luagents.Test.NoTypeInfo, :no_info)

      assert hd(tool.parameters).type == :string
    end
  end

  describe "union type annotations" do
    test "extracts union types from [type1|type2] annotations" do
      tool = Tool.from_function(Luagents.Test.UnionTypeTools, :test_union_brackets)

      assert length(tool.parameters) == 2
      [body, data] = tool.parameters

      assert body.name == "body"
      assert body.type == [:string, :table]
      assert body.description == "The request body (string or table)"

      assert data.name == "data"
      assert data.type == [:number, :string]
      assert data.description == "Numeric or string data"
    end

    test "extracts union types from (type1|type2) annotations" do
      tool = Tool.from_function(Luagents.Test.UnionTypeTools, :test_union_parens)

      assert length(tool.parameters) == 2
      [value, input] = tool.parameters

      assert value.name == "value"
      assert value.type == [:number, :boolean]
      assert value.description == "A value that can be number or boolean"

      assert input.name == "input"
      assert input.type == [:string, :table, :number]
      assert input.description == "Multi-type input"
    end

    test "single types still work as atoms" do
      tool = Tool.from_function(Luagents.Test.UnionTypeTools, :test_single_type)

      assert length(tool.parameters) == 2
      [name, count] = tool.parameters

      assert name.type == :string
      assert count.type == :number
    end

    test "formats union types correctly in prompts" do
      tool = Tool.from_function(Luagents.Test.UnionTypeTools, :test_union_brackets)
      formatted = Tool.format_for_prompt(tool)

      assert String.contains?(formatted, "body: string|table")
      assert String.contains?(formatted, "data: number|string")
    end

    test "formats single types correctly in prompts" do
      tool = Tool.from_function(Luagents.Test.UnionTypeTools, :test_single_type)
      formatted = Tool.format_for_prompt(tool)

      assert String.contains?(formatted, "name: string")
      assert String.contains?(formatted, "count: number")
    end

    test "handles complex union types with 3+ types" do
      tool = Tool.from_function(Luagents.Test.UnionTypeTools, :test_complex_union)

      [config, items] = tool.parameters

      assert config.type == [:string, :table, :boolean]
      assert items.type == [:table, :string]
    end

    test "formats complex union types in prompts" do
      tool = Tool.from_function(Luagents.Test.UnionTypeTools, :test_complex_union)
      formatted = Tool.format_for_prompt(tool)

      assert String.contains?(formatted, "config: string|table|boolean")
      assert String.contains?(formatted, "items: table|string")
    end
  end

  describe "HTTP tool union types" do
    test "extracts union type from HTTP.put body parameter" do
      tools = Tool.from_module(Luagents.Tools.Http)
      put_params = tools.put.parameters

      body_param = Enum.find(put_params, &(&1.name == "body"))
      assert body_param != nil
      assert body_param.type == [:string, :table]
      assert body_param.description == "The request body (string or table)"
    end

    test "formats HTTP.put with union type correctly" do
      tool = Tool.from_function(Luagents.Tools.Http, :put)
      formatted = Tool.format_for_prompt(tool)

      assert String.contains?(formatted, "body: string|table")
    end
  end
end
