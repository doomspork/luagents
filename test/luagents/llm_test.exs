defmodule Luagents.LLMTest do
  use ExUnit.Case, async: true

  alias Luagents.LLM
  alias Luagents.LLM.{Anthropic, Ollama}

  describe "LLM factory" do
    setup do
      System.delete_env("ANTHROPIC_API_KEY")
    end

    test "creates Anthropic LLM with explicit provider" do
      assert_raise ArgumentError, ~r/Anthropic API key not found/, fn ->
        LLM.new(provider: :anthropic, model: "claude-3-haiku-20240307")
      end
    end

    test "creates Anthropic LLM with API key" do
      llm = LLM.new(provider: :anthropic, api_key: "test-key")
      assert %Anthropic{} = llm
      assert llm.model == "claude-3-5-sonnet-20241022"
      assert llm.temperature == 0.7
    end

    test "creates Ollama LLM" do
      llm = LLM.new(provider: :ollama, model: "mistral")
      assert %Ollama{} = llm
      assert llm.model == "mistral"
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
end
