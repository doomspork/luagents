defmodule Luagents.LuaEngineTest do
  use ExUnit.Case, async: true

  alias Luagents.LuaEngine

  describe "new/0" do
    test "creates new Lua state with environment setup" do
      state = LuaEngine.new()

      assert %Lua{} = state

      {:continue, _new_state} = LuaEngine.execute(state, "local x = 1", %{})
    end
  end

  describe "execute/3" do
    test "executes simple Lua code" do
      state = LuaEngine.new()
      code = "local x = 5 + 3"

      assert {:continue, new_state} = LuaEngine.execute(state, code, %{})
      assert %Lua{} = new_state
    end

    test "returns final answer when provided" do
      state = LuaEngine.new()
      code = "final_answer('test result')"

      assert {:final_answer, "test result"} = LuaEngine.execute(state, code, %{})
    end

    test "captures print output in buffer" do
      state = LuaEngine.new()
      code = "print('hello'); print('world')"

      {:continue, new_state} = LuaEngine.execute(state, code, %{})
      buffer = Lua.get!(new_state, ["_print_buffer"])
      assert buffer == "hello\nworld\n"
    end

    test "handles thought and observation functions" do
      state = LuaEngine.new()

      code = """
      thought('thinking about this')
      observation('I see something')
      """

      {:continue, new_state} = LuaEngine.execute(state, code, %{})
      buffer = Lua.get!(new_state, ["_print_buffer"])
      assert String.contains?(buffer, "[THOUGHT] thinking about this")
      assert String.contains?(buffer, "[OBSERVATION] I see something")
    end

    test "handles compilation errors" do
      state = LuaEngine.new()
      code = "invalid lua syntax ("

      assert {:error, error_msg} = LuaEngine.execute(state, code, %{})
      assert String.starts_with?(error_msg, "Compilation error:")
    end

    test "handles runtime errors" do
      state = LuaEngine.new()
      code = "error('runtime error')"

      assert {:error, error_msg} = LuaEngine.execute(state, code, %{})
      assert String.starts_with?(error_msg, "Runtime error:")
    end

    test "injects tools correctly" do
      add_tool =
        Luagents.Tool.new(
          "add",
          "Add two numbers",
          [
            %{name: "a", type: :number, description: "First number", required: true},
            %{name: "b", type: :number, description: "Second number", required: true}
          ],
          fn [a, b] -> {:ok, a + b} end
        )

      state = LuaEngine.new()
      code = "local result = add(5, 3); final_answer(tostring(result))"
      tools = %{"add" => add_tool}

      assert {:final_answer, "8"} = LuaEngine.execute(state, code, tools)
    end

    test "handles tool execution errors gracefully" do
      failing_tool =
        Luagents.Tool.new(
          "fail",
          "Always fails",
          [],
          fn _ -> {:error, "tool failed"} end
        )

      state = LuaEngine.new()
      code = "local result = fail(); print('result:', result)"
      tools = %{"fail" => failing_tool}

      {:continue, new_state} = LuaEngine.execute(state, code, tools)
      buffer = Lua.get!(new_state, ["_print_buffer"])
      assert String.contains?(buffer, "result:")
    end

    test "clears print buffer between executions" do
      state = LuaEngine.new()
      code1 = "print('first')"
      code2 = "print('second')"

      {:continue, state1} = LuaEngine.execute(state, code1, %{})
      buffer1 = Lua.get!(state1, ["_print_buffer"])
      assert buffer1 == "first\n"

      {:continue, state2} = LuaEngine.execute(state1, code2, %{})
      buffer2 = Lua.get!(state2, ["_print_buffer"])
      assert buffer2 == "second\n"
    end

    test "preserves state between executions" do
      state = LuaEngine.new()
      code1 = "x = 42"
      code2 = "final_answer(tostring(x))"

      {:continue, state1} = LuaEngine.execute(state, code1, %{})
      assert {:final_answer, "42"} = LuaEngine.execute(state1, code2, %{})
    end
  end

  describe "special functions integration" do
    test "final_answer overwrites previous values" do
      state = LuaEngine.new()

      code = """
      final_answer('first')
      final_answer('second')
      """

      assert {:final_answer, "second"} = LuaEngine.execute(state, code, %{})
    end

    test "final_answer with complex data types" do
      state = LuaEngine.new()
      code = "final_answer({a = 1, b = 'test'})"

      assert {:final_answer, result} = LuaEngine.execute(state, code, %{})
      assert is_list(result)
      assert {"a", 1} in result
      assert {"b", "test"} in result
    end
  end
end
