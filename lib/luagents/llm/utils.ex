defmodule Luagents.LLM.Utils do
  @moduledoc """
  Utility functions shared across LLM implementations.
  """

  @doc """
  Extract Lua code from text that may contain markdown code blocks.

  First tries to extract from lua code blocks, then from generic code blocks.
  Returns the first code block found.
  If no code blocks are found, returns the original text.
  """
  @spec extract_lua_code(String.t()) :: String.t()
  def extract_lua_code(text) do
    case Regex.run(~r/```lua\s*(.*?)\s*```/s, text, capture: :all_but_first) do
      [code] ->
        String.trim(code)

      _ ->
        case Regex.run(~r/```\s*(.*?)\s*```/s, text, capture: :all_but_first) do
          [code] -> String.trim(code)
          _ -> text
        end
    end
  end

  @doc """
  Format error messages consistently across providers.
  """
  @spec format_error(any(), String.t()) :: String.t()
  def format_error(error, provider) when is_binary(error) do
    "#{provider} error: #{error}"
  end

  def format_error(error, provider) do
    "#{provider} error: #{inspect(error)}"
  end
end
