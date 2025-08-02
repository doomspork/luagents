defmodule Luagents.LuaEngine do
  @moduledoc """
  Lua execution engine for agent thoughts.
  Handles Lua code execution and tool invocations.
  """
  @type t :: Lua.t()

  def new do
    state = Lua.new()

    setup_environment(state)
  end

  def execute(state, code, tools) do
    state_with_tools = inject_tools(state, tools)

    state_with_special_functions = inject_special_functions(state_with_tools)

    {_, state_cleared} = Lua.eval!(state_with_special_functions, "_print_buffer = ''")

    try do
      {_, state_after_execution} = Lua.eval!(state_cleared, code)

      case get_final_answer(state_after_execution) do
        {:ok, answer} -> {:final_answer, answer}
        {:error, :not_found} -> {:continue, state_after_execution}
      end
    rescue
      error in Lua.RuntimeException ->
        {:error, "Runtime error: #{error.message}"}

      error in Lua.CompilerException ->
        {:error, "Compilation error: #{inspect(error.errors)}"}
    end
  end

  defp setup_environment(state) do
    {_, updated_state} =
      Lua.eval!(state, """
        function print(...)
          local args = {...}
          local str = ""
          for i, v in ipairs(args) do
            if i > 1 then str = str .. " " end
            str = str .. tostring(v)
          end
          _print_buffer = (_print_buffer or "") .. str .. "\\n"
          return str
        end

        function thought(msg)
          print("[THOUGHT] " .. msg)
        end

        function observation(msg)
          print("[OBSERVATION] " .. msg)
        end
      """)

    updated_state
  end

  defp inject_tools(state, tools) do
    Enum.reduce(tools, state, fn {name, tool}, acc_state ->
      Lua.set!(acc_state, [name], create_tool_wrapper(tool))
    end)
  end

  defp create_tool_wrapper(tool) do
    fn args ->
      case Luagents.Tool.execute(tool, args) do
        {:ok, result} -> result
        {:error, _error} -> nil
      end
    end
  end

  defp inject_special_functions(state) do
    state_with_final_answer = Lua.set!(state, ["_final_answer"], nil)

    {_, state_with_final_answer_function} =
      Lua.eval!(state_with_final_answer, """
        function final_answer(answer)
          _final_answer = answer
          return answer
        end
      """)

    state_with_final_answer_function
  end

  defp get_final_answer(state) do
    case Lua.get!(state, ["_final_answer"]) do
      nil -> {:error, :not_found}
      answer -> {:ok, answer}
    end
  end
end
