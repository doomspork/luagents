defmodule Luagents.APITest do
  use ExUnit.Case, async: true

  alias Luagents.Test.AltTypeTools
  alias Luagents.Test.NoTypeInfo
  alias Luagents.Test.TypeAnnotationTools
  alias Luagents.Test.UnionTypeTools
  alias Luagents.Tool
  alias Luagents.Tools.Http
  alias Luagents.Tools.Json

  describe "Luagents.API compile-time metadata generation" do
    test "generated metadata has correct structure" do
      metadata = Json.__luagent_tools__()

      assert is_map(metadata)
      assert Map.has_key?(metadata, :parse)
      assert Map.has_key?(metadata, :encode)
      assert Map.has_key?(metadata, :pretty)

      parse_meta = metadata.parse
      assert parse_meta.name == "json.parse"
      assert parse_meta.api == Json
      assert parse_meta.function_name == :parse
      assert is_binary(parse_meta.description)
      assert is_list(parse_meta.parameters)
    end

    test "generated metadata includes parameter information" do
      metadata = Json.__luagent_tools__()
      parse_meta = metadata.parse

      assert length(parse_meta.parameters) == 1
      [param] = parse_meta.parameters

      assert param.name == "json_string"
      assert param.type == :string
      assert param.required == true
      assert is_binary(param.description)
    end

    test "generated metadata respects scope configuration" do
      metadata = Json.__luagent_tools__()

      assert metadata.parse.name == "json.parse"
      assert metadata.encode.name == "json.encode"
      assert metadata.pretty.name == "json.pretty"
    end

    test "generated metadata extracts union types" do
      metadata = UnionTypeTools.__luagent_tools__()
      brackets_meta = metadata.test_union_brackets

      [body, data] = brackets_meta.parameters

      assert body.type == [:string, :table]
      assert body.name == "body"

      assert data.type == [:number, :string]
      assert data.name == "data"
    end

    test "generated metadata handles single types" do
      metadata = UnionTypeTools.__luagent_tools__()
      single_meta = metadata.test_single_type

      [name, count] = single_meta.parameters

      assert name.type == :string
      assert count.type == :number
    end
  end

  describe "Tool.from_module/2 with Luagents.API" do
    test "uses fast path for Luagents.API modules" do
      # Should not raise - fast path doesn't need Code.fetch_docs
      tools = Tool.from_module(Json)

      assert is_map(tools)
      assert Map.has_key?(tools, :parse)
      assert Map.has_key?(tools, :encode)
      assert Map.has_key?(tools, :pretty)
    end

    test "builds correct Tool structs from metadata" do
      tools = Tool.from_module(Json)
      parse_tool = tools.parse

      assert %Tool{} = parse_tool
      assert parse_tool.name == "json.parse"
      assert parse_tool.api == Json
      assert is_binary(parse_tool.description)
      assert length(parse_tool.parameters) == 1
    end

    test "supports :only option with fast path" do
      tools = Tool.from_module(Json, only: [:parse, :encode])

      assert Map.has_key?(tools, :parse)
      assert Map.has_key?(tools, :encode)
      refute Map.has_key?(tools, :pretty)
    end

    test "supports :except option with fast path" do
      tools = Tool.from_module(Json, except: [:pretty])

      assert Map.has_key?(tools, :parse)
      assert Map.has_key?(tools, :encode)
      refute Map.has_key?(tools, :pretty)
    end

    test "supports :param_types override with fast path" do
      tools =
        Tool.from_module(TypeAnnotationTools,
          param_types: %{name: :number}
        )

      process_tool = tools.process
      [name_param | _] = process_tool.parameters

      # Override should change type from :string to :number
      assert name_param.type == :number
    end

    @tag :skip
    test "fast path produces same results as slow path" do
      # Create a test module that uses Lua.API (slow path)
      defmodule SlowPathTest do
        use Lua.API

        @doc """
        Test function.

        ## Parameters
          - value [number]: A number value
        """
        deflua test_func(value) do
          {:ok, value}
        end
      end

      # Create equivalent module with Luagents.API (fast path)
      defmodule FastPathTest do
        use Luagents.API

        @doc """
        Test function.

        ## Parameters
          - value [number]: A number value
        """
        deflua test_func(value) do
          {:ok, value}
        end
      end

      slow_tools = Tool.from_module(SlowPathTest)
      fast_tools = Tool.from_module(FastPathTest)

      slow_tool = slow_tools.test_func
      fast_tool = fast_tools.test_func

      # Should have same structure (except api module)
      assert slow_tool.name == fast_tool.name
      assert slow_tool.description == fast_tool.description
      assert slow_tool.parameters == fast_tool.parameters
    end
  end

  describe "compile-time type extraction" do
    test "extracts types from @doc annotations" do
      metadata = TypeAnnotationTools.__luagent_tools__()
      process_meta = metadata.process

      [name, count, enabled, data] = process_meta.parameters

      assert name.type == :string
      assert count.type == :number
      assert enabled.type == :boolean
      assert data.type == :table
    end

    test "handles parentheses annotation style" do
      metadata = TypeAnnotationTools.__luagent_tools__()
      parens_meta = metadata.test_parens

      [value, items] = parens_meta.parameters

      assert value.type == :number
      assert items.type == :table
    end

    test "handles alternative type names" do
      metadata = AltTypeTools.__luagent_tools__()
      alt_meta = metadata.test_alt

      [items, mapping, collection] = alt_meta.parameters

      # list, map, array should all map to :table
      assert items.type == :table
      assert mapping.type == :table
      assert collection.type == :table
    end

    test "defaults to :string when no type info" do
      metadata = NoTypeInfo.__luagent_tools__()
      no_info_meta = metadata.no_info

      [param] = no_info_meta.parameters
      assert param.type == :string
    end
  end

  describe "backward compatibility" do
    @tag :skip
    test "Lua.API modules still work via slow path" do
      defmodule LegacyModule do
        use Lua.API, scope: "legacy"

        @doc """
        Legacy function.

        ## Parameters
          - value [string]: A value
        """
        deflua legacy_func(value) do
          {:ok, value}
        end
      end

      # Should not have fast path function
      refute function_exported?(LegacyModule, :__luagent_tools__, 0)

      # But from_module should still work
      tools = Tool.from_module(LegacyModule)
      assert Map.has_key?(tools, :legacy_func)

      legacy_tool = tools.legacy_func
      assert legacy_tool.name == "legacy.legacy_func"
      assert length(legacy_tool.parameters) == 1
    end
  end

  describe "Tool.format_for_prompt/1 with compiled metadata" do
    test "formats union types correctly" do
      tools = Tool.from_module(UnionTypeTools)
      brackets_tool = tools.test_union_brackets

      formatted = Tool.format_for_prompt(brackets_tool)

      assert formatted =~ "test_union_brackets"
      assert formatted =~ "body: string|table"
      assert formatted =~ "data: number|string"
    end

    test "formats single types correctly" do
      tools = Tool.from_module(Json)
      parse_tool = tools.parse

      formatted = Tool.format_for_prompt(parse_tool)

      assert formatted =~ "json.parse"
      assert formatted =~ "json_string: string"
    end
  end

  describe "HTTP tool with compile-time metadata" do
    test "extracts union type for body parameter" do
      metadata = Http.__luagent_tools__()

      # POST, PUT, PATCH should have body parameter with union type
      post_meta = metadata.post
      body_param = Enum.find(post_meta.parameters, &(&1.name == "body"))

      assert body_param.type == [:string, :table]
    end
  end
end
