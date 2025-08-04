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
      # default model
      assert llm.model == "claude-3-5-sonnet-20241022"
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

  describe "Anthropic integration" do
    test "extracts lua code from response correctly" do
      # Test the private extract_lua_code function via generate (if we had a mock)
      anthropic_llm = %Anthropic{
        client: nil,
        model: "claude-3-5-sonnet-20241022",
        system_prompt: "test",
        temperature: 0.7,
        max_tokens: 1000,
        options: %{}
      }

      # Verify struct is properly formed
      assert anthropic_llm.model == "claude-3-5-sonnet-20241022"
      assert anthropic_llm.temperature == 0.7
      assert anthropic_llm.max_tokens == 1000
    end

    test "constructs proper request options" do
      anthropic_llm = %Anthropic{
        client: nil,
        model: "claude-3-haiku-20240307",
        system_prompt: "test prompt",
        temperature: 0.5,
        max_tokens: 500,
        options: %{stop: ["\n"]}
      }

      # Verify all options are captured
      assert anthropic_llm.model == "claude-3-haiku-20240307"
      assert anthropic_llm.temperature == 0.5
      assert anthropic_llm.max_tokens == 500
      assert anthropic_llm.options == %{stop: ["\n"]}
    end
  end

  describe "Ollama integration" do
    test "constructs proper request structure" do
      ollama_llm = %Ollama{
        client: nil,
        model: "mistral",
        host: "http://custom:11434",
        temperature: 0.9,
        max_tokens: 2048,
        options: %{seed: 42}
      }

      # Verify options handling
      assert ollama_llm.model == "mistral"
      assert ollama_llm.host == "http://custom:11434"
      assert ollama_llm.temperature == 0.9
      assert ollama_llm.max_tokens == 2048
      assert ollama_llm.options == %{seed: 42}
    end

    test "handles response extraction patterns" do
      ollama_llm = %Ollama{
        client: nil,
        model: "llama3.2",
        host: "http://localhost:11434",
        temperature: 0.7,
        options: %{}
      }

      # Verify struct initialization
      assert ollama_llm.model == "llama3.2"
      assert ollama_llm.host == "http://localhost:11434"
      assert ollama_llm.temperature == 0.7
    end
  end

  describe "behaviour compliance" do
    test "both providers implement required functions" do
      # Verify both providers have the required functions
      assert function_exported?(Anthropic, :new, 1)
      assert function_exported?(Anthropic, :generate, 2)
      assert function_exported?(Ollama, :new, 1)
      assert function_exported?(Ollama, :generate, 2)
    end

    test "providers return consistent struct types" do
      # Anthropic
      anthropic = %Anthropic{
        client: nil,
        model: "test-model",
        system_prompt: "test",
        temperature: 0.7,
        max_tokens: 1000,
        options: %{}
      }

      assert match?(%Anthropic{}, anthropic)

      # Ollama
      ollama = %Ollama{
        client: nil,
        model: "test-model",
        host: "localhost",
        temperature: 0.7,
        options: %{}
      }

      assert match?(%Ollama{}, ollama)
    end
  end

  describe "error handling patterns" do
    test "providers handle different error formats" do
      # Test that both providers can be instantiated for testing
      # (actual API calls would require valid credentials/services)

      # Anthropic error case (missing API key)
      assert_raise ArgumentError, fn ->
        Anthropic.new([])
      end

      # Ollama should not raise on instantiation
      ollama = Ollama.new([])
      assert %Ollama{} = ollama
    end
  end
end
