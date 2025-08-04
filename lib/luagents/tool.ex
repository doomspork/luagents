defmodule Luagents.Tool do
  @moduledoc """
  Tool definition and execution for the ReAct agent.
  Tools are functions that the agent can call from Lua code.
  """

  defstruct [
    :api,
    :name,
    :description,
    :parameters,
    :function
  ]

  @type t :: %__MODULE__{
          api: module() | nil,
          description: String.t(),
          function: func() | nil,
          name: String.t(),
          parameters: [parameter()]
        }

  @type parameter :: %{
          name: String.t(),
          type: :string | :number | :boolean | :table,
          description: String.t(),
          required: boolean()
        }

  @type func :: (list(any()) -> {:ok, any()} | {:error, any()})

  @type api :: module()

  @spec new(String.t(), String.t(), [parameter()], func()) :: t()
  def new(name, description, parameters, function_or_api) do
    function = if is_function(function_or_api), do: function_or_api, else: nil
    api = if is_atom(function_or_api), do: function_or_api, else: nil

    %__MODULE__{
      api: api,
      description: description,
      function: function,
      name: name,
      parameters: parameters
    }
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
end
