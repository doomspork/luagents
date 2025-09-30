defmodule Luagents.Tools.JsonTest do
  use ExUnit.Case, async: false

  import Luagents.Test.LuaToolTestHelper

  alias Luagents.Tool
  alias Luagents.Tools.Json

  setup do
    tools = Tool.from_module(Json, prefix: "json_")
    lua = setup_lua_with_tools(tools)
    {:ok, lua: lua}
  end

  describe "json_parse/1" do
    test "parses valid JSON object from Lua", %{lua: lua} do
      code = """
      local result = json_parse("{\\\"name\\\": \\\"Alice\\\", \\\"age\\\": 30}")
      return result.name .. ":" .. result.age
      """

      result = eval_lua(lua, code)
      assert result == "Alice:30"
    end

    test "parses valid JSON array from Lua", %{lua: lua} do
      code = """
      local result = json_parse("[1, 2, 3, 4, 5]")
      return result[1] + result[2] + result[3] + result[4] + result[5]
      """

      result = eval_lua(lua, code)
      assert result == 15
    end

    test "parses nested JSON structures from Lua", %{lua: lua} do
      code = """
      local result = json_parse("{\\\"user\\\": {\\\"name\\\": \\\"Bob\\\", \\\"tags\\\": [\\\"admin\\\", \\\"user\\\"]}}")
      return result.user.name .. ":" .. result.user.tags[1]
      """

      result = eval_lua(lua, code)
      assert result == "Bob:admin"
    end

    test "parses JSON with numbers and booleans from Lua", %{lua: lua} do
      code = """
      local result = json_parse("{\\\"count\\\": 42, \\\"active\\\": true, \\\"score\\\": 3.14}")
      if result.active then
        return result.count + result.score
      end
      """

      result = eval_lua(lua, code)
      assert result == 45.14
    end

    test "returns nil for invalid JSON from Lua", %{lua: lua} do
      code = "return json_parse(\"invalid json here\")"
      result = eval_lua(lua, code)
      assert result == nil
    end

    test "parses empty JSON object from Lua", %{lua: lua} do
      code = """
      local result = json_parse("{}")
      local count = 0
      for k, v in pairs(result) do
        count = count + 1
      end
      return count
      """

      result = eval_lua(lua, code)
      assert result == 0
    end

    test "parses empty JSON array from Lua", %{lua: lua} do
      code = """
      local result = json_parse("[]")
      return #result
      """

      result = eval_lua(lua, code)
      # Lua's # operator returns nil for empty tables
      assert result == nil || result == 0
    end

    test "handles JSON with special characters from Lua", %{lua: lua} do
      code = """
      local result = json_parse("{\\\"message\\\": \\\"Hello\\\\nWorld\\\\t!\\\"}")
      if result.message and string.find(result.message, "Hello") then
        return "ok"
      end
      """

      result = eval_lua(lua, code)
      assert result == "ok"
    end

    test "parses JSON in Lua control structures", %{lua: lua} do
      code = """
      local data = {}
      for i = 1, 3 do
        local json = "{\\\"index\\\": " .. i .. "}"
        data[i] = json_parse(json)
      end
      return data[1].index + data[2].index + data[3].index
      """

      result = eval_lua(lua, code)
      assert result == 6
    end

    test "builds JSON string dynamically and parses in Lua", %{lua: lua} do
      code = """
      local items = {"apple", "banana", "cherry"}
      local json_items = "["
      for i, item in ipairs(items) do
        if i > 1 then json_items = json_items .. "," end
        json_items = json_items .. '"' .. item .. '"'
      end
      json_items = json_items .. "]"
      local result = json_parse(json_items)
      return result[1] .. "," .. result[2] .. "," .. result[3]
      """

      result = eval_lua(lua, code)
      assert result == "apple,banana,cherry"
    end
  end

  describe "json_encode/1" do
    test "encodes Lua table to JSON string", %{lua: lua} do
      code = """
      local json = json_encode({name = "Alice", age = 30})
      if json and string.find(json, "Alice") and string.find(json, "30") then
        return "ok"
      end
      """

      result = eval_lua(lua, code)
      assert result == "ok"
    end

    test "encodes Lua array to JSON", %{lua: lua} do
      code = """
      local json = json_encode({1, 2, 3, 4, 5})
      return json
      """

      result = eval_lua(lua, code)
      assert result == "[1,2,3,4,5]"
    end

    test "encodes nested Lua structures", %{lua: lua} do
      code = """
      local json = json_encode({user = {name = "Bob", tags = {"admin", "user"}}})
      if json and string.find(json, "Bob") then
        return "ok"
      end
      """

      result = eval_lua(lua, code)
      assert result == "ok"
    end

    test "encodes primitive types from Lua", %{lua: lua} do
      assert "42" == eval_lua(lua, "return json_encode(42)")
      assert "true" == eval_lua(lua, "return json_encode(true)")
      assert "false" == eval_lua(lua, "return json_encode(false)")
      assert "\"hello\"" == eval_lua(lua, "return json_encode(\"hello\")")
    end

    test "encodes empty structures from Lua", %{lua: lua} do
      # Empty Lua table can encode to either {} or [] depending on context
      code = """
      local json = json_encode({})
      return json == "{}" or json == "[]"
      """

      result = eval_lua(lua, code)
      assert result == true
    end

    test "handles nil result on encode error", %{lua: lua} do
      # Attempting to encode something that can't be JSON encoded
      code = """
      local func = function() end
      return json_encode(func)
      """

      result = eval_lua(lua, code)
      assert result == nil
    end

    test "encodes and accesses nested data from Lua", %{lua: lua} do
      code = """
      local data = {
        user = {
          name = "Alice",
          settings = {
            theme = "dark",
            notifications = true
          }
        }
      }
      local json = json_encode(data)
      local parsed = json_parse(json)
      return parsed.user.settings.theme
      """

      result = eval_lua(lua, code)
      assert result == "dark"
    end
  end

  describe "json_pretty/1" do
    test "pretty prints JSON with indentation from Lua", %{lua: lua} do
      code = """
      local json = json_pretty({name = "Alice", age = 30})
      if json and string.find(json, "\\n") and string.find(json, "  ") then
        return "ok"
      end
      """

      result = eval_lua(lua, code)
      assert result == "ok"
    end

    test "pretty prints nested structures from Lua", %{lua: lua} do
      code = """
      local json = json_pretty({user = {name = "Bob"}})
      if json and string.find(json, "\\n") then
        return "ok"
      end
      """

      result = eval_lua(lua, code)
      assert result == "ok"
    end
  end

  describe "integration scenarios" do
    test "round-trip: encode then decode from Lua", %{lua: lua} do
      code = """
      local original = {name = "Alice", numbers = {1, 2, 3}, active = true}
      local json = json_encode(original)
      local decoded = json_parse(json)
      if decoded.name == "Alice" and decoded.numbers[2] == 2 and decoded.active == true then
        return "ok"
      end
      """

      result = eval_lua(lua, code)
      assert result == "ok"
    end
  end
end
