defmodule Luagents.AgentTest do
  use ExUnit.Case, async: true

  alias Luagents.{Agent, Memory}
  alias Luagents.LLM.Utils

  defmodule MockLLM do
    @behaviour Luagents.LLM.Behaviour

    defstruct [:responses]

    def new(responses) when is_list(responses), do: %__MODULE__{responses: responses}

    def new(_opts), do: %__MODULE__{responses: []}

    def generate(%MockLLM{responses: [response | _rest]}, _prompt) do
      # Extract Lua code like real LLM providers do
      extracted_code = Utils.extract_lua_code(response)
      {:ok, extracted_code}
    end

    def generate(%MockLLM{responses: []}, _prompt) do
      {:error, "No more mock responses"}
    end
  end

  describe "new/1" do
    test "creates agent with default values" do
      agent = Agent.new()

      assert agent.max_iterations == 10
      assert %Memory{} = agent.memory
      assert agent.name == "Luagent"
      assert agent.tools == %{}
      assert agent.lua_state != nil
    end

    test "creates agent with custom options" do
      memory = %Memory{messages: []}
      tools = %{"test" => nil}

      agent =
        Agent.new(
          max_iterations: 5,
          memory: memory,
          name: "CustomAgent",
          tools: tools
        )

      assert agent.max_iterations == 5
      assert agent.memory == memory
      assert agent.name == "CustomAgent"
      assert agent.tools == tools
    end

    test "accepts custom LLM" do
      mock_llm = MockLLM.new(["final_answer('test')"])
      agent = Agent.new(llm: mock_llm)

      assert agent.llm == mock_llm
    end
  end

  describe "run/2" do
    test "returns error when max iterations reached" do
      # Create a mock that always returns continue (never final_answer)
      mock_llm = MockLLM.new(["print('continue')", "print('still going')"])
      agent = Agent.new(llm: mock_llm, max_iterations: 1)

      assert {:error, "Maximum iterations reached"} = Agent.run(agent, "test task")
    end

    test "returns final answer when provided" do
      mock_llm = MockLLM.new(["final_answer('success')"])
      agent = Agent.new(llm: mock_llm)

      assert {:ok, "success"} = Agent.run(agent, "test task")
    end

    test "handles LLM errors" do
      mock_llm = MockLLM.new([])
      agent = Agent.new(llm: mock_llm)

      assert {:error, "No more mock responses"} = Agent.run(agent, "test task")
    end
  end

  describe "integration" do
    test "completes simple calculation task" do
      mock_llm =
        MockLLM.new([
          """
          ```lua
          local result = 2 + 3
          final_answer(tostring(result))
          ```
          """
        ])

      agent = Agent.new(llm: mock_llm, max_iterations: 5)

      assert {:ok, "5"} = Agent.run(agent, "What is 2 + 3?")
    end

    test "uses basic Lua computation" do
      mock_llm =
        MockLLM.new([
          """
          local x = 10
          local y = 20
          final_answer(tostring(x + y))
          """
        ])

      agent = Agent.new(llm: mock_llm)

      assert {:ok, "30"} = Agent.run(agent, "Calculate 10 + 20")
    end
  end
end
