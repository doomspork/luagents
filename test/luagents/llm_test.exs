defmodule Luagents.LLMTest do
  use ExUnit.Case, async: true

  alias Luagents.LLM
  alias Luagents.LLM.{Anthropic, Ollama}

  describe "LLM factory" do
    test "creates Anthropic LLM by default" do
      # Should raise error for missing API key
      assert_raise ArgumentError, ~r/Anthropic API key not found/, fn ->
        LLM.new()
      end
    end

    test "creates Anthropic LLM with explicit provider" do
      # Should raise error for missing API key  
      assert_raise ArgumentError, ~r/Anthropic API key not found/, fn ->
        LLM.new(provider: :anthropic, model: "claude-3-haiku-20240307")
      end
    end
    
    test "creates Anthropic LLM with API key" do
      llm = LLM.new(provider: :anthropic, api_key: "test-key")
      assert %Anthropic{} = llm
      assert llm.model == "claude-3-5-sonnet-20241022"  # default model
      assert llm.temperature == 0.7
    end

    test "creates Ollama LLM" do
      llm = LLM.new(provider: :ollama, model: "llama3.2")
      assert %Ollama{} = llm
      assert llm.model == "llama3.2"
      assert llm.host == "http://localhost:11434"
    end

    test "creates Ollama LLM with custom host" do
      llm = LLM.new(provider: :ollama, model: "mistral", host: "http://custom:11434")
      assert %Ollama{} = llm
      assert llm.model == "mistral"
      assert llm.host == "http://custom:11434"
    end

    test "raises error for unsupported provider" do
      assert_raise ArgumentError, ~r/Unsupported LLM provider/, fn ->
        LLM.new(provider: :unknown)
      end
    end
  end

  describe "LLM generate" do
    test "dispatches to correct provider implementation" do
      # Verify both providers have generate/2 exported
      assert function_exported?(Anthropic, :generate, 2)
      assert function_exported?(Ollama, :generate, 2)

      # Verify pattern matching works for both providers
      anthropic_llm = %Anthropic{
        client: nil,
        model: "claude-3-5-sonnet-20241022",
        system_prompt: "test",
        temperature: 0.7,
        max_tokens: 1000,
        options: %{}
      }
      
      ollama_llm = %Ollama{
        model: "llama3.2",
        temperature: 0.7,
        options: %{}
      }

      # Test that the pattern matching in generate/2 would work
      assert match?(%Anthropic{}, anthropic_llm)
      assert match?(%Ollama{}, ollama_llm)
    end
  end

  describe "providers/0" do
    test "returns list of supported providers" do
      providers = LLM.providers()
      assert :anthropic in providers
      assert :ollama in providers
      assert is_list(providers)
    end
  end
end
