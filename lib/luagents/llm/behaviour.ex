defmodule Luagents.LLM.Behaviour do
  @moduledoc """
  Behaviour for LLM implementations in Luagents.
  
  All LLM providers must implement this behaviour to ensure consistency
  in the interface and expected functionality.
  """

  @doc """
  Create a new LLM instance with the given options.
  
  ## Parameters
  - `opts` - Keyword list of options specific to the LLM provider
  
  ## Returns
  A struct representing the configured LLM instance.
  """
  @callback new(opts :: Keyword.t()) :: struct()

  @doc """
  Generate a response from the LLM for the given prompt.
  
  ## Parameters
  - `llm` - The LLM instance struct
  - `prompt` - The prompt string to send to the LLM
  
  ## Returns
  - `{:ok, response}` - Successfully generated response
  - `{:error, reason}` - Error during generation
  """
  @callback generate(llm :: struct(), prompt :: String.t()) :: 
    {:ok, String.t()} | {:error, String.t()}
end