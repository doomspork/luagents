defmodule Luagents.Tools.LoggerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Luagents.Test.LuaToolTestHelper

  alias Luagents.Tool
  alias Luagents.Tools.Logger, as: LoggerTool

  setup do
    tools = Tool.from_module(LoggerTool, prefix: "log_")
    lua = setup_lua_with_tools(tools)
    {:ok, lua: lua}
  end

  test "logs debug message from Lua", %{lua: lua} do
    log =
      capture_log([level: :debug], fn ->
        assert_lua_ok(lua, ~s[log_debug("Debug from Lua")])
      end)

    assert log =~ "Debug from Lua"
  end

  test "logs info message from Lua", %{lua: lua} do
    log =
      capture_log(fn ->
        assert_lua_ok(lua, ~s[log_info("Info from Lua")])
      end)

    assert log =~ "Info from Lua"
  end

  test "logs warning message from Lua", %{lua: lua} do
    log =
      capture_log(fn ->
        assert_lua_ok(lua, ~s[log_warning("Warning from Lua")])
      end)

    assert log =~ "Warning from Lua"
  end

  test "logs error message from Lua", %{lua: lua} do
    log =
      capture_log(fn ->
        assert_lua_ok(lua, ~s[log_error("Error from Lua")])
      end)

    assert log =~ "Error from Lua"
  end

  test "logs with metadata from Lua", %{lua: lua} do
    log =
      capture_log(fn ->
        code = ~s[log_info("info", "Action from Lua", {user_id = 456, action = "test"})]
        assert_lua_ok(lua, code)
      end)

    assert log =~ "Action from Lua"
  end

  test "handles multiple log calls in sequence from Lua", %{lua: lua} do
    log =
      capture_log([level: :debug], fn ->
        code = """
        log_debug("First message")
        log_info("Second message")
        log_warning("Third message")
        """

        assert_lua_ok(lua, code)
      end)

    assert log =~ "First message"
    assert log =~ "Second message"
    assert log =~ "Third message"
  end

  test "logging within Lua control structures", %{lua: lua} do
    log =
      capture_log(fn ->
        code = """
        for i = 1, 3 do
          log_info("Iteration " .. i)
        end
        """

        assert_lua_ok(lua, code)
      end)

    assert log =~ "Iteration 1"
    assert log =~ "Iteration 2"
    assert log =~ "Iteration 3"
  end

  test "logging with string concatenation from Lua", %{lua: lua} do
    log =
      capture_log(fn ->
        code = """
        local name = "Alice"
        local age = 30
        log_info("User: " .. name .. ", Age: " .. age)
        """

        assert_lua_ok(lua, code)
      end)

    assert log =~ "User: Alice, Age: 30"
  end

  test "returns ok atom directly from Lua", %{lua: lua} do
    result = eval_lua(lua, ~s[return log_info("Test return value")])
    assert result == nil
  end
end
