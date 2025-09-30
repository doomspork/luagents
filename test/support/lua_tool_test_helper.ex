defmodule Luagents.Test.LuaToolTestHelper do
  @moduledoc """
  Test helper for evaluating tool functionality via Lua code execution.

  Provides utilities to test tools through the Lua execution layer without
  requiring an LLM, ensuring tools work correctly when called from Lua.

  ## Examples

      # Setup
      lua = setup_lua_with_tools([logger_tools])

      # Execute Lua code and get result
      result = eval_lua(lua, ~s(log_info("test message")))
      assert result == :logged

      # Execute Lua code that returns a value
      result = eval_lua(lua, ~s(return 2 + 2))
      assert result == 4

      # Test with final_answer
      {:ok, answer} = eval_lua_final(lua, ~s(final_answer("done")))
      assert answer == "done"
  """

  alias Luagents.LuaEngine

  @doc """
  Creates a new Lua state with the given tools injected.

  ## Parameters
    - tools: A map of tools or list of tool maps to inject

  ## Returns
    - A Lua state ready for execution

  ## Examples

      tools = Tool.from_module(Luagents.Tools.Logger)
      lua = setup_lua_with_tools(tools)
  """
  def setup_lua_with_tools(tools) when is_map(tools) do
    state = LuaEngine.new()
    inject_tools(state, tools)
  end

  def setup_lua_with_tools(tool_list) when is_list(tool_list) do
    merged_tools = Enum.reduce(tool_list, %{}, &Map.merge/2)
    setup_lua_with_tools(merged_tools)
  end

  @doc """
  Executes Lua code and returns the result.

  Uses a special `_test_result` variable to capture the last expression value.

  ## Parameters
    - lua_state: The Lua state with tools injected
    - code: Lua code to execute

  ## Returns
    - The result of the last Lua expression, or nil if no result

  ## Examples

      result = eval_lua(lua, "return 5 + 3")
      assert result == 8

      result = eval_lua(lua, "log_info('test'); return 'ok'")
      assert result == "ok"
  """
  def eval_lua(lua_state, code) do
    # Wrap code to capture the last result
    # Handle both 'return value' and plain statements
    wrapped_code = """
    _test_result = (function()
      #{code}
    end)()
    """

    try do
      {_, state_after} = Lua.eval!(lua_state, wrapped_code)

      case Lua.get!(state_after, ["_test_result"]) do
        nil -> nil
        result -> convert_lua_value(result)
      end
    rescue
      error in Lua.RuntimeException ->
        {:error, "Runtime error: #{error.message}"}

      error in Lua.CompilerException ->
        {:error, "Compilation error: #{inspect(error.errors)}"}
    end
  end

  @doc """
  Executes Lua code and returns the final_answer if called.

  ## Parameters
    - lua_state: The Lua state with tools injected
    - code: Lua code to execute

  ## Returns
    - {:ok, answer} if final_answer was called
    - {:continue, state} if final_answer was not called
    - {:error, reason} if execution failed

  ## Examples

      {:ok, answer} = eval_lua_final(lua, ~s(final_answer("done")))
      assert answer == "done"

      {:continue, _state} = eval_lua_final(lua, ~s(log_info("test")))
  """
  def eval_lua_final(lua_state, code) do
    case LuaEngine.execute(lua_state, code, %{}) do
      {:final_answer, answer} -> {:ok, answer}
      {:continue, state} -> {:continue, state}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Executes Lua code and captures print output.

  ## Parameters
    - lua_state: The Lua state with tools injected
    - code: Lua code to execute

  ## Returns
    - {result, print_output} tuple

  ## Examples

      {result, output} = eval_lua_with_output(lua, ~s(
        print("hello")
        print("world")
        return 42
      ))
      assert result == 42
      assert output =~ "hello"
      assert output =~ "world"
  """
  def eval_lua_with_output(lua_state, code) do
    # Clear print buffer
    {_, cleared_state} = Lua.eval!(lua_state, "_print_buffer = ''")

    # Wrap code to capture result AND preserve state
    wrapped_code = """
    _test_result = (function()
      #{code}
    end)()
    """

    try do
      {_, state_after} = Lua.eval!(cleared_state, wrapped_code)

      # Get result
      result =
        case Lua.get!(state_after, ["_test_result"]) do
          nil -> nil
          r -> convert_lua_value(r)
        end

      # Get print buffer
      output =
        case Lua.get!(state_after, ["_print_buffer"]) do
          nil -> ""
          buffer -> buffer
        end

      {result, output}
    rescue
      error in Lua.RuntimeException ->
        {{:error, "Runtime error: #{error.message}"}, ""}

      error in Lua.CompilerException ->
        {{:error, "Compilation error: #{inspect(error.errors)}"}, ""}
    end
  end

  @doc """
  Asserts that Lua code executes without errors.

  ## Parameters
    - lua_state: The Lua state with tools injected
    - code: Lua code to execute

  ## Examples

      assert_lua_ok(lua, ~s(log_info("test")))
  """
  def assert_lua_ok(lua_state, code) do
    case eval_lua(lua_state, code) do
      {:error, reason} ->
        raise "Lua execution failed: #{reason}"

      _ ->
        :ok
    end
  end

  @doc """
  Asserts that Lua code raises an error.

  ## Parameters
    - lua_state: The Lua state with tools injected
    - code: Lua code to execute

  ## Examples

      assert_lua_error(lua, ~s(error("expected error")))
  """
  def assert_lua_error(lua_state, code) do
    case eval_lua(lua_state, code) do
      {:error, _reason} -> :ok
      _ -> raise "Expected Lua code to error, but it succeeded"
    end
  end

  # Private functions

  defp inject_tools(state, tools) do
    # Group tools by API module to avoid loading the same API multiple times
    tools_by_api =
      tools
      |> Enum.filter(fn {_name, tool} -> is_atom(tool.api) and not is_nil(tool.api) end)
      |> Enum.group_by(fn {_name, tool} -> tool.api end)

    # Load API modules first
    state_with_apis =
      tools_by_api
      |> Map.keys()
      |> Enum.reduce(state, fn api_module, acc_state ->
        Lua.load_api(acc_state, api_module)
      end)

    # Then create aliases/wrappers for prefixed names
    Enum.reduce(tools, state_with_apis, fn
      {func_name, tool}, acc_state when is_atom(tool.api) ->
        # If the tool name differs from function name (due to prefix), create an alias
        func_name_str = Atom.to_string(func_name)

        if tool.name != func_name_str do
          # Get the loaded function and assign it to the prefixed name
          {_, state_with_alias} = Lua.eval!(acc_state, "#{tool.name} = #{func_name}")
          state_with_alias
        else
          acc_state
        end

      {name, tool}, acc_state when is_function(tool.function) ->
        Lua.set!(acc_state, [to_string(name)], create_tool_wrapper(tool))

      _, acc_state ->
        acc_state
    end)
  end

  defp create_tool_wrapper(tool) do
    fn args ->
      try do
        case tool.function.(args) do
          {:ok, result} -> result
          {:error, _error} -> nil
        end
      rescue
        e -> {:error, Exception.format(:error, e, __STACKTRACE__)}
      end
    end
  end

  # Convert Lua values to Elixir equivalents
  defp convert_lua_value(value) when is_map(value) do
    # Lua tables come as maps, convert string keys
    Map.new(value, fn {k, v} -> {k, convert_lua_value(v)} end)
  end

  defp convert_lua_value(value) when is_list(value) do
    Enum.map(value, &convert_lua_value/1)
  end

  defp convert_lua_value(value), do: value
end
