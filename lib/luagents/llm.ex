defmodule Luagents.LLM do
  @moduledoc """
  LLM factory and interface for the ReAct agent.

  Supports multiple LLM providers:
  - Anthropic Claude (via Anthropix)
  - Ollama (local models)

  The effectiveness of this ReAct agent heavily depends on the underlying model's reasoning capabilities and code generation quality.
  For best results, use a high-quality model with strong logical reasoning and programming skills.

  ## Usage

      # Create an Anthropic LLM (default)
      llm = LLM.new(provider: :anthropic)

      # Create an Ollama LLM
      llm = LLM.new(provider: :ollama, model: "mistral")

      # Generate a response
      {:ok, response} = LLM.generate(llm, "Your prompt here")
  """

  alias Luagents.LLM.{Anthropic, Ollama}

  @type provider :: :anthropic | :ollama
  @type t :: Anthropic.t() | Ollama.t()

  @default_provider :ollama

  @doc """
  Create a new LLM instance with the specified provider.

  ## Options

  - `:provider` - The LLM provider to use (`:anthropic` or `:ollama`)
  - Additional options are passed to the specific provider's `new/1` function

  ## Examples

      # Use Anthropic Claude (default)
      LLM.new()
      LLM.new(provider: :anthropic, model: "claude-3-haiku-20240307")

      # Use Ollama
      LLM.new(provider: :ollama)
      LLM.new(provider: :ollama, model: "mistral", host: "http://localhost:11434")
  """
  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    provider = Keyword.get(opts, :provider, @default_provider)
    provider_opts = Keyword.delete(opts, :provider)

    case provider do
      :anthropic ->
        Anthropic.new(provider_opts)

      :ollama ->
        Ollama.new(provider_opts)

      _ ->
        raise ArgumentError,
              "Unsupported LLM provider: #{inspect(provider)}. Supported providers: :anthropic, :ollama"
    end
  end

  @doc """
  Generate a response from the LLM.

  The LLM instance determines which provider implementation to use.
  """
  @spec generate(t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate(%module{} = llm, prompt), do: module.generate(llm, prompt)
end
