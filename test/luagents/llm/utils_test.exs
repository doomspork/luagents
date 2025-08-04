defmodule Luagents.LLM.UtilsTest do
  use ExUnit.Case, async: true

  alias Luagents.LLM.Utils

  describe "extract_lua_code/1" do
    test "extracts code from lua code blocks" do
      text = """
      Here's some Lua code:
      ```lua
      local x = 5
      print(x)
      ```
      That's the code.
      """

      result = Utils.extract_lua_code(text)
      assert result == "local x = 5\nprint(x)"
    end

    test "extracts code from generic code blocks when no lua blocks" do
      text = """
      Here's some code:
      ```
      local y = 10
      final_answer(y)
      ```
      End of code.
      """

      result = Utils.extract_lua_code(text)
      assert result == "local y = 10\nfinal_answer(y)"
    end

    test "prioritizes lua blocks over generic blocks" do
      text = """
      Generic block:
      ```
      generic code
      ```

      Lua block:
      ```lua
      lua code
      ```
      """

      result = Utils.extract_lua_code(text)
      assert result == "lua code"
    end

    test "returns original text when no code blocks found" do
      text = "Just plain text with no code blocks"

      result = Utils.extract_lua_code(text)
      assert result == text
    end

    test "handles empty code blocks" do
      text = """
      ```lua
      ```
      """

      result = Utils.extract_lua_code(text)
      assert result == ""
    end

    test "handles code blocks with extra whitespace" do
      text = """
      ```lua

        local x = 1
        local y = 2
        
      ```
      """

      result = Utils.extract_lua_code(text)
      assert result == "local x = 1\n  local y = 2"
    end

    test "handles multiline code blocks" do
      text = """
      ```lua
      function test()
        local a = 5
        local b = 10
        return a + b
      end

      local result = test()
      final_answer(result)
      ```
      """

      expected = """
      function test()
        local a = 5
        local b = 10
        return a + b
      end

      local result = test()
      final_answer(result)
      """

      result = Utils.extract_lua_code(text)
      assert result == String.trim(expected)
    end

    test "handles code blocks with special characters" do
      text = """
      ```lua
      local str = "Hello \"world\""
      local pattern = [[pattern with \\ backslashes]]
      ```
      """

      result = Utils.extract_lua_code(text)
      assert String.contains?(result, "Hello \"world\"")
      assert String.contains?(result, "pattern with \\ backslashes")
    end

    test "handles mixed content with multiple blocks" do
      text = """
      First there's some explanation.

      ```
      some generic code
      ```

      But then we have the main Lua code:

      ```lua
      thought("This is the real code")
      final_answer(42)
      ```

      And more text after.
      """

      result = Utils.extract_lua_code(text)
      assert result == "thought(\"This is the real code\")\nfinal_answer(42)"
    end
  end

  describe "format_error/2" do
    test "formats string errors" do
      error = "Connection timeout"
      provider = "Anthropic"

      result = Utils.format_error(error, provider)
      assert result == "Anthropic error: Connection timeout"
    end

    test "formats non-string errors with inspect" do
      error = {:error, :timeout}
      provider = "Ollama"

      result = Utils.format_error(error, provider)
      assert result == "Ollama error: {:error, :timeout}"
    end

    test "formats exception structs" do
      error = %RuntimeError{message: "Something went wrong"}
      provider = "TestProvider"

      result = Utils.format_error(error, provider)
      assert String.starts_with?(result, "TestProvider error:")
      assert String.contains?(result, "RuntimeError")
    end

    test "formats maps and complex data" do
      error = %{code: 400, message: "Bad request"}
      provider = "API"

      result = Utils.format_error(error, provider)
      assert result == "API error: %{code: 400, message: \"Bad request\"}"
    end

    test "formats atoms" do
      error = :connection_failed
      provider = "Network"

      result = Utils.format_error(error, provider)
      assert result == "Network error: :connection_failed"
    end

    test "formats lists" do
      error = ["Error 1", "Error 2"]
      provider = "Batch"

      result = Utils.format_error(error, provider)
      assert result == "Batch error: [\"Error 1\", \"Error 2\"]"
    end
  end

  describe "base_system_prompt/0" do
    test "returns basic system prompt" do
      prompt = Utils.base_system_prompt()

      assert is_binary(prompt)
      assert String.contains?(prompt, "ReAct agent")
      assert String.contains?(prompt, "thought(message)")
      assert String.contains?(prompt, "observation(message)")
      assert String.contains?(prompt, "final_answer(answer)")
      assert String.contains?(prompt, "Lua code block")
    end

    test "prompt is well-formed" do
      prompt = Utils.base_system_prompt()

      # Should be substantial but not too long (this is the fallback)
      assert String.length(prompt) > 100
      assert String.length(prompt) < 1000

      # Should be trimmed properly (remove trailing newline from test)
      assert String.trim(prompt) != ""
    end
  end

  describe "edge cases and integration" do
    test "extract_lua_code handles malformed regex patterns" do
      # Text that might cause regex issues
      text = "```lua\n[[[complex pattern]]]\n```"

      result = Utils.extract_lua_code(text)
      assert result == "[[[complex pattern]]]"
    end

    test "format_error handles very long error messages" do
      long_error = String.duplicate("error ", 1000)

      result = Utils.format_error(long_error, "Test")
      assert String.starts_with?(result, "Test error:")
      assert String.contains?(result, "error error error")
    end

    test "extract_lua_code with nested backticks" do
      text = """
      ```lua
      local code = "`echo hello`"
      print(code)
      ```
      """

      result = Utils.extract_lua_code(text)
      assert String.contains?(result, "`echo hello`")
    end
  end
end
