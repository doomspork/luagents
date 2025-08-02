defmodule Luagents.Agent do
  @moduledoc """
  Core ReAct agent that thinks using Lua code.
  Inspired by smolagents but uses Lua for reasoning.
  """
  alias Luagents.{Memory, LLM, LuaEngine}

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
    default_llm =
      case Keyword.get(opts, :llm) do
        nil ->
          try do
            LLM.new(provider: :ollama, model: "llama3.1")
          rescue
            _ -> nil
          end

        llm ->
          llm
      end

    %__MODULE__{
      llm: default_llm,
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

    case LLM.generate(agent.llm, prompt) do
      {:ok, lua_code} ->
        agent = put_in(agent.memory, Memory.add_message(agent.memory, :assistant, lua_code))

        case LuaEngine.execute(agent.lua_state, lua_code, agent.tools) do
          {:final_answer, answer} ->
            {:ok, answer}

          {:continue, new_lua_state} ->
            print_output = Lua.get!(new_lua_state, ["_print_buffer"]) || ""

            agent = %{agent | lua_state: new_lua_state}
            agent = maybe_add_print_output(agent, print_output)

            run_loop(agent, iteration + 1)

          {:error, error} ->
            agent =
              put_in(
                agent.memory,
                Memory.add_message(agent.memory, :system, "Error: #{inspect(error)}")
              )

            run_loop(agent, iteration + 1)
        end

      {:error, llm_error} ->
        {:error, llm_error}
    end
  end

  defp build_prompt(agent) do
    Luagents.Prompts.system_prompt(agent.tools, agent.memory)
  end

  defp maybe_add_print_output(agent, print_output) when print_output != "" do
    put_in(
      agent.memory,
      Memory.add_message(agent.memory, :system, print_output)
    )
  end

  defp maybe_add_print_output(agent, _print_output), do: agent
end
