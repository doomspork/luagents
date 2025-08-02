defmodule Luagents.LLM.Utils do
  @moduledoc """
  Utility functions shared across LLM implementations.
  """

  @doc """
  Extract Lua code from text that may contain markdown code blocks.
  """
  @spec extract_lua_code(String.t()) :: String.t()
  def extract_lua_code(text) do
    # First try to extract from lua code blocks
    case Regex.run(~r/```lua\s*(.*?)\s*```/s, text, capture: :all_but_first) do
      [code] -> 
        String.trim(code)
        
      _ ->
        # Try generic code blocks
        case Regex.run(~r/```\s*(.*?)\s*```/s, text, capture: :all_but_first) do
          [code] -> String.trim(code)
          _ -> text  # Return original text if no code blocks found
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

  @doc """
  Basic system prompt for LLMs (fallback).
  This is typically overridden by the main system prompt.
  """
  @spec base_system_prompt() :: String.t()
  def base_system_prompt do
    """
    You are an expert ReAct agent who can solve any task using Lua code.
    
    You have access to these special functions:
    - thought(message): Log your reasoning process
    - observation(message): Note what you observe
    - final_answer(answer): Provide the final answer
    
    Your response should be a single Lua code block.
    """
  end
end