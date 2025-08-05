defmodule Luagents.LLM.Ollama do
  @moduledoc """
  Ollama LLM implementation for the ReAct agent.
  """

  @behaviour Luagents.LLM.Behaviour

  alias Luagents.LLM.Utils

  defstruct [
    :client,
    :host,
    :max_tokens,
    :model,
    :options,
    :temperature
  ]

  @type t :: %__MODULE__{
          client: any(),
          host: String.t(),
          max_tokens: pos_integer() | nil,
          model: String.t(),
          options: map(),
          temperature: float()
        }

  @default_model "mistral"
  @default_temperature 0.7

  @impl true
  def new(opts \\ []) do
    client = Ollama.init()

    %__MODULE__{
      client: client,
      host: Keyword.get(opts, :host, "http://localhost:11434"),
      max_tokens: Keyword.get(opts, :max_tokens, nil),
      model: Keyword.get(opts, :model, @default_model),
      options: Keyword.get(opts, :options, %{}),
      temperature: Keyword.get(opts, :temperature, @default_temperature)
    }
  end

  @impl true
  def generate(%__MODULE__{} = llm, prompt) do
    request_options = %{temperature: llm.temperature}

    request_options =
      if llm.max_tokens do
        Map.put(request_options, :num_predict, llm.max_tokens)
      else
        request_options
      end

    case Ollama.completion(llm.client,
           model: llm.model,
           prompt: prompt,
           stream: false,
           options: Map.merge(request_options, llm.options)
         ) do
      {:ok, %{"response" => response}} ->
        {:ok, Utils.extract_lua_code(response)}

      {:ok, response} ->
        extract_content_from_response(response)

      {:error, error} ->
        {:error, Utils.format_error(error, "Ollama")}
    end
  end

  defp extract_content_from_response(response) do
    case Map.get(response, "response") do
      nil ->
        {:error, "Unexpected response format from Ollama API"}

      response_text ->
        {:ok, Utils.extract_lua_code(response_text)}
    end
  end
end
