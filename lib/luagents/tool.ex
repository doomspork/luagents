defmodule Luagents.Tool do
  @moduledoc """
  Tool definition and execution for the ReAct agent.
  Tools are functions that the agent can call from Lua code.
  """

  defstruct [
    :name,
    :description,
    :parameters,
    :function
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          parameters: [parameter()],
          function: func()
        }

  @type parameter :: %{
          name: String.t(),
          type: :string | :number | :boolean | :table,
          description: String.t(),
          required: boolean()
        }

  @type func :: (list(any()) -> {:ok, any()} | {:error, any()})

  @spec new(String.t(), String.t(), [parameter()], func()) :: t()
  def new(name, description, parameters, function) do
    %__MODULE__{
      description: description,
      function: function,
      name: name,
      parameters: parameters
    }
  end

  @spec execute(t(), list(any())) :: {:ok, any()} | {:error, any()}
  def execute(%__MODULE__{function: function}, args) do
    function.(args)
  rescue
    e -> {:error, Exception.format(:error, e, __STACKTRACE__)}
  end

  def format_for_prompt(%__MODULE__{} = tool) do
    params = format_parameters(tool.parameters)

    """
    - #{tool.name}(#{params}): #{tool.description}
    """
  end

  defp format_parameters(parameters) do
    Enum.map_join(parameters, ", ", fn param ->
      required = if param.required, do: "", else: "?"
      "#{param.name}#{required}: #{param.type}"
    end)
  end

  def builtin_tools do
    %{
      "add" =>
        new(
          "add",
          "Add two numbers",
          [
            %{name: "a", type: :number, description: "First number", required: true},
            %{name: "b", type: :number, description: "Second number", required: true}
          ],
          fn [a, b] -> {:ok, a + b} end
        ),
      "multiply" =>
        new(
          "multiply",
          "Multiply two numbers",
          [
            %{name: "a", type: :number, description: "First number", required: true},
            %{name: "b", type: :number, description: "Second number", required: true}
          ],
          fn [a, b] -> {:ok, a * b} end
        ),
      "concat" =>
        new(
          "concat",
          "Concatenate strings",
          [
            %{
              name: "strings",
              type: :table,
              description: "List of strings to concatenate",
              required: true
            }
          ],
          fn [strings] when is_list(strings) ->
            {:ok, Enum.join(strings, "")}
          end
        ),
      "search" =>
        new(
          "search",
          "Search for information (mock implementation)",
          [
            %{name: "query", type: :string, description: "Search query", required: true}
          ],
          fn [query] ->
            # Mock search results
            {:ok, "Mock search results for: #{query}"}
          end
        )
    }
  end
end
