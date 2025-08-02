defmodule Luagents do
  @moduledoc """
  ReAct Agent implementation that thinks using Lua.
  Inspired by smolagents but uses Lua for reasoning.

  This module provides a high-level interface for creating and running ReAct agents
  that use Lua code for step-by-step reasoning and tool execution.

  ## Quick Start

      # Run a simple task with default configuration
      {:ok, answer} = Luagents.run("What is 15 + 25?")

      # Create a custom agent with specific LLM provider
      agent = Luagents.create_agent(
        name: "MathBot",
        llm: Luagents.create_llm(:ollama, model: "llama3.2"),
        max_iterations: 5
      )

      {:ok, result} = Luagents.run_with_agent(agent, "Calculate the area of a circle with radius 10")

  ## LLM Providers

  Supports multiple LLM providers:
  - `:anthropic` - Claude models (default)
  - `:ollama` - Local Ollama models

  ## Built-in Tools

  Comes with several built-in tools:
  - `add(a, b)` - Add two numbers
  - `multiply(a, b)` - Multiply two numbers
  - `concat(strings)` - Concatenate strings
  - `search(query)` - Search for information (mock)

  """

  alias Luagents.{Agent, Tool, LLM, Memory}

  ## Public API

  @doc """
  Run a task with the default agent configuration.

  Uses Anthropic Claude by default with all built-in tools.

  ## Options

  - `:tools` - Map of tools to provide to the agent (defaults to builtin tools)
  - `:llm` - LLM instance to use (defaults to Anthropic)
  - `:max_iterations` - Maximum reasoning iterations (default: 10)
  - `:name` - Agent name for identification

  ## Examples

      # Simple calculation
      {:ok, answer} = Luagents.run("What is 10 + 20?")

      # With custom tools
      custom_tools = Map.merge(Luagents.builtin_tools(), %{
        "greet" => Luagents.create_tool("greet", "Say hello", [], fn _ -> {:ok, "Hello!"} end)
      })
      {:ok, response} = Luagents.run("Greet me", tools: custom_tools)

  """
  @spec run(String.t(), Keyword.t()) :: {:ok, String.t()} | {:error, String.t()}
  def run(task, opts \\ []) do
    agent = create_agent(opts)
    run_with_agent(agent, task)
  end

  @doc """
  Create a new agent with custom configuration.

  ## Options

  - `:name` - Agent name (default: "Luagent")
  - `:llm` - LLM instance (default: Anthropic Claude)
  - `:tools` - Map of available tools (default: builtin tools)
  - `:max_iterations` - Maximum reasoning iterations (default: 10)
  - `:memory` - Initial memory state (default: empty)

  ## Examples

      # Basic agent
      agent = Luagents.create_agent()

      # Custom agent with Ollama
      agent = Luagents.create_agent(
        name: "LocalAgent",
        llm: Luagents.create_llm(:ollama, model: "mistral"),
        max_iterations: 15
      )

      # Agent with custom tools
      tools = Map.put(Luagents.builtin_tools(), "custom", my_tool)
      agent = Luagents.create_agent(tools: tools)

  """
  @spec create_agent(Keyword.t()) :: Agent.t()
  def create_agent(opts \\ []) do
    opts = Keyword.put_new(opts, :tools, Tool.builtin_tools())

    Agent.new(opts)
  end

  @doc """
  Run a task with a specific agent instance.

  This allows you to reuse an agent across multiple tasks, maintaining
  any stateful configuration while getting fresh memory for each task.

  ## Examples

      agent = Luagents.create_agent(name: "MathBot")

      {:ok, result1} = Luagents.run_with_agent(agent, "What is 5 + 3?")
      {:ok, result2} = Luagents.run_with_agent(agent, "What is 10 * 4?")

  """
  @spec run_with_agent(Agent.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def run_with_agent(agent, task) do
    Agent.run(agent, task)
  end

  ## LLM Management

  @doc """
  Create an LLM instance for use with agents.

  ## Providers

  - `:anthropic` - Claude models (requires ANTHROPIC_API_KEY)
  - `:ollama` - Local Ollama models (requires Ollama server running)

  ## Examples

      # Default Anthropic Claude
      llm = Luagents.create_llm(:anthropic)

      # Specific Claude model
      llm = Luagents.create_llm(:anthropic, model: "claude-3-haiku-20240307")

      # Ollama with local model
      llm = Luagents.create_llm(:ollama, model: "llama3.2")

      # Custom Ollama host
      llm = Luagents.create_llm(:ollama, model: "mistral", host: "http://192.168.1.100:11434")

  """
  @spec create_llm(LLM.provider(), Keyword.t()) :: LLM.t()
  def create_llm(provider, opts \\ []) do
    LLM.new([provider: provider] ++ opts)
  end

  @doc """
  Get available LLM providers.

  ## Examples

      iex> Luagents.llm_providers()
      [:anthropic, :ollama]

  """
  @spec llm_providers() :: [LLM.provider()]
  def llm_providers, do: LLM.providers()

  ## Tool Management

  @doc """
  Get the map of built-in tools.

  ## Examples

      iex> tools = Luagents.builtin_tools()
      iex> Map.keys(tools) |> Enum.sort()
      ["add", "concat", "multiply", "search"]

  """
  @spec builtin_tools() :: %{String.t() => Tool.t()}
  def builtin_tools, do: Tool.builtin_tools()

  @doc """
  Create a custom tool for use with agents.

  ## Parameters

  - `name` - Tool name (used in Lua code)
  - `description` - Human-readable description
  - `parameters` - List of parameter specifications
  - `function` - Function that executes the tool

  ## Examples

      # Simple tool with no parameters
      greet_tool = Luagents.create_tool(
        "greet",
        "Say hello",
        [],
        fn _ -> {:ok, "Hello, World!"} end
      )

      # Tool with parameters
      power_tool = Luagents.create_tool(
        "power",
        "Raise a number to a power",
        [
          %{name: "base", type: :number, description: "Base number", required: true},
          %{name: "exponent", type: :number, description: "Exponent", required: true}
        ],
        fn [base, exp] -> {:ok, :math.pow(base, exp)} end
      )

  """
  @spec create_tool(String.t(), String.t(), [Tool.parameter()], Tool.func()) :: Tool.t()
  def create_tool(name, description, parameters, function) do
    Tool.new(name, description, parameters, function)
  end

  @doc """
  List available tool names from a tool map.

  ## Examples

      iex> Luagents.list_tools(Luagents.builtin_tools()) |> Enum.sort()
      ["add", "concat", "multiply", "search"]

  """
  @spec list_tools(%{String.t() => Tool.t()}) :: [String.t()]
  def list_tools(tools) when is_map(tools) do
    Map.keys(tools)
  end

  ## Agent Introspection

  @doc """
  Get the current memory state of an agent.

  Returns the conversation history as a list of messages.

  ## Examples

      agent = Luagents.create_agent()
      # ... run some tasks ...
      messages = Luagents.get_agent_memory(agent)

  """
  @spec get_agent_memory(Agent.t()) :: [Memory.message()]
  def get_agent_memory(%Agent{memory: memory}) do
    Memory.get_messages(memory)
  end

  @doc """
  Get agent configuration details.

  ## Examples

      agent = Luagents.create_agent(name: "TestBot", max_iterations: 5)
      info = Luagents.get_agent_info(agent)
      # => %{name: "TestBot", max_iterations: 5, tool_count: 4, memory_size: 0}

  """
  @spec get_agent_info(Agent.t()) :: map()
  def get_agent_info(%Agent{} = agent) do
    %{
      name: agent.name,
      max_iterations: agent.max_iterations,
      tool_count: map_size(agent.tools),
      memory_size: length(Memory.get_messages(agent.memory))
    }
  end

  @doc """
  Create an agent with cleared memory but same configuration.

  Useful for starting fresh conversations with the same agent setup.

  ## Examples

      agent = Luagents.create_agent(name: "Bot")
      # ... run some tasks ...
      fresh_agent = Luagents.reset_agent_memory(agent)

  """
  @spec reset_agent_memory(Agent.t()) :: Agent.t()
  def reset_agent_memory(%Agent{} = agent) do
    %{agent | memory: Memory.new()}
  end

  ## Convenience Functions

  @doc """
  Quick test if the system is working with a simple math problem.

  ## Examples

      iex> case Luagents.test() do
      ...>   {:ok, _result} -> :ok
      ...>   {:error, "Ollama error: " <> _} -> :ok  # Expected when Ollama not running
      ...>   {:error, reason} -> {:error, reason}
      ...> end
      :ok

  """
  @spec test() :: {:ok, String.t()} | {:error, String.t()}
  def test do
    run("What is 2 + 2? Use the add tool to calculate this.")
  end

  @doc """
  Get version information and status.

  ## Examples

      iex> Luagents.status()
      %{
        version: "0.1.0",
        llm_providers: [:anthropic, :ollama],
        builtin_tools: ["add", "concat", "multiply", "search"],
        default_max_iterations: 10
      }

  """
  @spec status() :: map()
  def status do
    %{
      version: Application.spec(:luagents, :vsn) |> to_string(),
      llm_providers: llm_providers(),
      builtin_tools: list_tools(builtin_tools()) |> Enum.sort(),
      default_max_iterations: 10
    }
  end
end
