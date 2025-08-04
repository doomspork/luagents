defmodule Luagents.LLM.Anthropic do
  @moduledoc """
  Anthropic Claude LLM implementation for the ReAct agent.
  """

  @behaviour Luagents.LLM.Behaviour

  defstruct [
    :client,
    :model,
    :system_prompt,
    :temperature,
    :max_tokens,
    :options
  ]

  @type t :: %__MODULE__{
          client: any(),
          model: String.t(),
          system_prompt: String.t(),
          temperature: float(),
          max_tokens: pos_integer(),
          options: map()
        }

  @default_max_tokens 2048
  @default_model "claude-3-5-sonnet-20241022"
  @default_temperature 0.7

  @impl true
  def new(opts \\ []) do
    api_key = get_api_key(opts)
    client = Anthropix.init(api_key)

    # Get the default system prompt
    system_prompt = Keyword.get(opts, :system_prompt, default_system_prompt())

    %__MODULE__{
      client: client,
      model: Keyword.get(opts, :model, @default_model),
      system_prompt: system_prompt,
      temperature: Keyword.get(opts, :temperature, @default_temperature),
      max_tokens: Keyword.get(opts, :max_tokens, @default_max_tokens),
      options: Keyword.get(opts, :options, %{})
    }
  end

  @impl true
  def generate(%__MODULE__{} = llm, prompt) do
    # Combine system prompt with user prompt
    full_prompt = """
    #{llm.system_prompt}

    Now write code to solve the user's task:
    #{prompt}
    """

    messages = [
      %{role: "user", content: full_prompt}
    ]

    options = [
      max_tokens: llm.max_tokens,
      messages: messages,
      model: llm.model,
      temperature: llm.temperature
    ]

    # Merge any additional options
    final_options = Keyword.merge(options, Map.to_list(llm.options))

    case Anthropix.chat(llm.client, final_options) do
      {:ok, %{"content" => [%{"text" => response} | _]}} ->
        extract_lua_code(response)

      {:ok, %{"content" => content}} when is_list(content) ->
        text =
          Enum.map_join(content, "\n", fn
            %{"text" => t} -> t
            _ -> ""
          end)

        extract_lua_code(text)

      {:error, error} ->
        {:error, format_anthropic_error(error)}
    end
  end

  defp get_api_key(opts) do
    # Priority: 1. Passed option, 2. Environment variable, 3. Application config
    Keyword.get(opts, :api_key) ||
      System.get_env("ANTHROPIC_API_KEY") ||
      Application.get_env(:luagents, :anthropic_api_key) ||
      raise ArgumentError, """
      Anthropic API key not found. Please provide it via one of:
      1. Pass as option: Luagents.create_llm(:anthropic, api_key: "your-key")
      2. Set environment variable: export ANTHROPIC_API_KEY="your-key"
      3. Configure in config: config :luagents, :anthropic_api_key, "your-key"
      """
  end

  defp extract_lua_code(text) do
    # Extract Lua code from markdown code blocks
    case Regex.run(~r/```lua\s*(.*?)\s*```/s, text, capture: :all_but_first) do
      [code] ->
        {:ok, String.trim(code)}

      _ ->
        # If no lua block found, check for generic code block
        case Regex.run(~r/```\s*(.*?)\s*```/s, text, capture: :all_but_first) do
          [code] -> {:ok, String.trim(code)}
          _ -> {:error, "No Lua code found in response"}
        end
    end
  end

  defp format_anthropic_error(error) do
    case error do
      %{message: message} when is_binary(message) ->
        "Anthropic API error: #{message}"

      %{reason: reason} when is_binary(reason) ->
        "Anthropic API error: #{reason}"

      error when is_exception(error) ->
        "Anthropic API error: #{Exception.message(error)}"

      error ->
        "Anthropic API error: #{inspect(error)}"
    end
  end

  defp default_system_prompt do
    # This will be overridden by the prompt from Luagents.Prompts.system_prompt/2
    # but we provide a basic one as fallback
    """
    You are an expert ReAct agent who can solve any task using Lua code.
    You will be given a task to solve as best you can.

    You have access to these special functions:
    - thought(message): Log your reasoning process
    - observation(message): Note what you observe
    - final_answer(answer): Provide the final answer

    Your response should be a single Lua code block.
    """
  end
end
