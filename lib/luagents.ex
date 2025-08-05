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
        llm: Luagents.create_llm(:ollama, model: "mistral"),
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

  alias Luagents.{Agent, LLM, Memory, Tool}

  ## Public API

  @doc """
  Run a task with the default agent configuration.

  Uses Anthropic Claude by default with all built-in tools.

  ## Options

  - `:tools` - Map of tools to provide to the agent
  - `:llm` - LLM instance to use (defaults to Ollama)
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
      agent = Luagents.create_agent(tools: %{
        "custom" => Luagents.create_tool("custom", "Custom tool", [], fn _ -> "Custom tool" end)
      })

  """
  @spec create_agent(Keyword.t()) :: Agent.t()
  def create_agent(opts \\ []) do
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

      # Anthropic Claude model
      llm = Luagents.create_llm(:anthropic, model: "claude-3-haiku-20240307")

      # Ollama with local model
      llm = Luagents.create_llm(:ollama, model: "mistral")

      # Custom Ollama host
      llm = Luagents.create_llm(:ollama, model: "mistral", host: "http://192.168.1.100:11434")

  """
  @spec create_llm(LLM.provider(), Keyword.t()) :: LLM.t()
  def create_llm(provider, opts \\ []) do
    LLM.new([provider: provider] ++ opts)
  end

  @doc """
  Create a custom tool for use with agents.

  ## Parameters

  - `name` - Tool name (used in Lua code)
  - `description` - Human-readable description
  - `parameters` - List of parameter specifications
  - `function_or_api` - Function that executes the tool or a module that implements the deflua API

  ## Examples

      # Simple tool with no parameters
      greet_tool = Luagents.create_tool(
        "greet",
        "Say hello",
        [],
        fn _ -> "Hello, World!" end
      )

      # Tool with parameters
      power_tool = Luagents.create_tool(
        "power",
        "Raise a number to a power",
        [
          %{name: "base", type: :number, description: "Base number", required: true},
          %{name: "exponent", type: :number, description: "Exponent", required: true}
        ],
        fn [base, exp] -> :math.pow(base, exp) end
      )

      # Tool with deflua macro API
      defmodule WebSearch do
        use Lua.API

        deflua search(query) do
          # Implement search logic here
        end
      end

      tool = Luagents.create_tool(
        "search",
        "Search the web",
        [%{name: "query", type: :string, description: "Search query", required: true}],
        WebSearch
      )

  """
  @spec create_tool(String.t(), String.t(), [Tool.parameter()], Tool.func() | Tool.api()) :: Tool.t()
  def create_tool(name, description, parameters, function_or_api) do
    Tool.new(name, description, parameters, function_or_api)
  end

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
end
