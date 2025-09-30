defmodule Luagents.Agent do
  @moduledoc """
  Core ReAct agent that thinks using Lua code.
  Inspired by smolagents but uses Lua for reasoning.
  """
  alias Luagents.{LLM, LuaEngine, Memory}

  defstruct [
    :llm,
    :lua_state,
    :max_iterations,
    :memory,
    :name,
    :tools
  ]

  @type t :: %__MODULE__{
          llm: LLM.t(),
          lua_state: LuaEngine.t(),
          max_iterations: pos_integer(),
          memory: Memory.t(),
          name: String.t(),
          tools: map()
        }

  @default_max_iterations 10

  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    llm = Keyword.get_lazy(opts, :llm, fn -> LLM.new() end)

    %__MODULE__{
      llm: llm,
      lua_state: LuaEngine.new(),
      max_iterations: Keyword.get(opts, :max_iterations, @default_max_iterations),
      memory: Keyword.get(opts, :memory, %Memory{}),
      name: Keyword.get(opts, :name, "Luagent"),
      tools: Keyword.get(opts, :tools, %{})
    }
  end

  @spec run(t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def run(agent, task) do
    agent = put_in(agent.memory, Memory.add_message(agent.memory, :user, task))

    run_loop(agent, 0)
  end

  defp run_loop(agent, iteration) when iteration >= agent.max_iterations do
    {:error, "Maximum iterations reached"}
  end

  defp run_loop(agent, iteration) do
    prompt = build_prompt(agent)

    with {:ok, lua_code} <- LLM.generate(agent.llm, prompt) do
      agent
      |> add_message(:assistant, lua_code)
      |> execute_lua_code(lua_code)
      |> handle_execution_result(iteration)
    end
  end

  defp execute_lua_code(agent, lua_code) do
    {agent, LuaEngine.execute(agent.lua_state, lua_code, agent.tools)}
  end

  defp handle_execution_result({_agent, {:final_answer, answer}}, _iteration) do
    {:ok, answer}
  end

  defp handle_execution_result({agent, {:continue, new_lua_state}}, iteration) do
    print_output = Lua.get!(new_lua_state, ["_print_buffer"]) || ""

    agent
    |> Map.put(:lua_state, new_lua_state)
    |> add_print_output(print_output)
    |> run_loop(iteration + 1)
  end

  defp handle_execution_result({agent, {:error, error}}, iteration) do
    agent
    |> add_message(:system, "Error: #{inspect(error)}")
    |> run_loop(iteration + 1)
  end

  defp add_message(agent, role, content) do
    put_in(agent.memory, Memory.add_message(agent.memory, role, content))
  end

  defp add_print_output(agent, "") do
    agent
  end

  defp add_print_output(agent, print_output) do
    add_message(agent, :system, print_output)
  end

  defp build_prompt(agent) do
    Luagents.Prompts.system_prompt(agent.tools, agent.memory)
  end
end
