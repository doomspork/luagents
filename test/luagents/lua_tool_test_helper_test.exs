defmodule Luagents.Test.LuaToolTestHelperTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Luagents.Test.LuaToolTestHelper

  alias Luagents.Tool

  setup do
    tools = Tool.from_module(Luagents.Tools.Logger, prefix: "log_")
    lua = setup_lua_with_tools(tools)
    {:ok, lua: lua}
  end

  describe "setup_lua_with_tools/1" do
    test "can setup with multiple tool modules" do
      logger_tools = Tool.from_module(Luagents.Tools.Logger, prefix: "log_")
      json_tools = Tool.from_module(Luagents.Tools.Json, prefix: "json_")

      lua = setup_lua_with_tools([logger_tools, json_tools])

      result = eval_lua(lua, "return json_encode({test = 'value'})")
      assert is_binary(result)
      assert result =~ "test"
    end
  end

  describe "eval_lua/2" do
    test "executes basic Lua code and returns result", %{lua: lua} do
      result = eval_lua(lua, "return 2 + 2")
      assert result == 4
    end

    test "executes Lua code with string result", %{lua: lua} do
      result = eval_lua(lua, "return 'hello world'")
      assert result == "hello world"
    end

    test "calls injected tool from Lua", %{lua: lua} do
      log =
        capture_log(fn ->
          result = eval_lua(lua, "return log_info('test message')")
          assert result == nil
        end)

      assert log =~ "test message"
    end

    test "handles multiple tool calls in sequence", %{lua: lua} do
      log =
        capture_log([level: :debug], fn ->
          code = """
          log_debug('debug msg')
          log_info('info msg')
          log_warning('warning msg')
          return 'done'
          """

          result = eval_lua(lua, code)
          assert result == "done"
        end)

      assert log =~ "debug msg"
      assert log =~ "info msg"
      assert log =~ "warning msg"
    end

    test "handles nil return values", %{lua: lua} do
      result = eval_lua(lua, "local x = 5")
      assert result == nil
    end

    test "handles Lua runtime error by logging and returning nil", %{lua: lua} do
      result = eval_lua(lua, "error('test error')")
      assert result == nil
    end

    test "returns error tuple on Lua syntax error", %{lua: lua} do
      result = eval_lua(lua, "this is invalid lua syntax (")
      assert {:error, error_msg} = result
      assert error_msg =~ "Compilation error"
    end

    test "works with tool that has metadata parameter", %{lua: lua} do
      log =
        capture_log(fn ->
          code = """
          return log_log('info', 'user action', {user_id = 123, action = 'login'})
          """

          result = eval_lua(lua, code)
          assert result == nil
        end)

      assert log =~ "user action"
    end
  end

  describe "eval_lua_final/2" do
    test "returns final_answer", %{lua: lua} do
      {:ok, answer} = eval_lua_final(lua, "final_answer('completed')")
      assert answer == "completed"
    end

    test "returns continue when no final_answer", %{lua: lua} do
      {:continue, _state} = eval_lua_final(lua, "log_info('test')")
    end
  end

  describe "eval_lua_with_output/2" do
    test "captures print output", %{lua: lua} do
      {result, output} =
        eval_lua_with_output(lua, """
        print('hello')
        print('world')
        return 42
        """)

      assert result == 42
      assert output =~ "hello"
      assert output =~ "world"
    end
  end

  describe "assert_lua_ok/2" do
    test "passes on successful execution", %{lua: lua} do
      assert_lua_ok(lua, "return 1 + 1")
    end

    test "raises on Lua syntax error", %{lua: lua} do
      assert_raise RuntimeError, ~r/Lua execution failed/, fn ->
        assert_lua_ok(lua, "this is invalid syntax (")
      end
    end
  end

  describe "assert_lua_error/2" do
    test "passes on Lua syntax error", %{lua: lua} do
      assert_lua_error(lua, "invalid syntax (")
    end

    test "raises when code succeeds", %{lua: lua} do
      assert_raise RuntimeError, ~r/Expected Lua code to error/, fn ->
        assert_lua_error(lua, "return 'success'")
      end
    end
  end
end
