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

  @spec new(String.t(), String.t(), [parameter()], func() | api()) :: t()
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

  @doc """
  Create tools from all exported functions in a module.

  Automatically extracts tool metadata from module documentation and function signatures.
  This is the recommended way to register deflua-based tools.

  ## Options
    - `:prefix` - String prefix to add to all tool names (e.g., "json_")
    - `:only` - List of function names to include (atoms)
    - `:except` - List of function names to exclude (atoms)
    - `:param_types` - Map of parameter names (atoms) to types (:string, :number, :boolean, :table)

  ## Examples

      # Generate all tools from a module
      tools = Tool.from_module(Luagents.Tools.Json)
      # => %{parse: %Tool{...}, encode: %Tool{...}, pretty: %Tool{...}}

      # With prefix
      tools = Tool.from_module(Luagents.Tools.Json, prefix: "json_")
      # => %{parse: %Tool{name: "json_parse", ...}, ...}

      # Only specific functions
      tools = Tool.from_module(Luagents.Tools.Json, only: [:parse, :encode])

      # With type overrides
      tools = Tool.from_module(MyModule, param_types: %{count: :number, data: :table})

  """
  @spec from_module(module(), keyword()) :: %{atom() => t()}
  def from_module(module, opts \\ []) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, :elixir, _, _, _, docs} ->
        docs
        |> filter_functions(opts)
        |> Enum.map(&build_tool_from_doc(module, &1, opts))
        |> Map.new()

      {:error, reason} ->
        raise ArgumentError,
              "Could not fetch docs for #{inspect(module)}: #{inspect(reason)}. " <>
                "Make sure the module is compiled with docs enabled."
    end
  end

  @doc """
  Create a tool from a specific function in a module.

  Automatically extracts metadata from the function's documentation.

  ## Options
    - `:as` - Custom tool name (string)
    - `:param_types` - Map of parameter names (atoms) to types

  ## Examples

      tool = Tool.from_function(Luagents.Tools.Json, :parse)
      # => %Tool{name: "parse", ...}

      tool = Tool.from_function(Luagents.Tools.Json, :parse,
        as: "json_parse",
        param_types: %{json_string: :string}
      )

  """
  @spec from_function(module(), atom(), keyword()) :: t()
  def from_function(module, func_name, opts \\ []) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, :elixir, _, _, _, docs} ->
        case find_function_doc(docs, func_name) do
          nil ->
            raise ArgumentError,
                  "Function #{func_name} not found in #{inspect(module)}. " <>
                    "Make sure it's exported and documented."

          doc ->
            {_name, tool} = build_tool_from_doc(module, doc, opts)
            tool
        end

      {:error, reason} ->
        raise ArgumentError,
              "Could not fetch docs for #{inspect(module)}: #{inspect(reason)}"
    end
  end

  defp filter_functions(docs, opts) do
    only = Keyword.get(opts, :only)
    except = Keyword.get(opts, :except, [])

    lua_api_functions = [:__lua_functions__, :scope, :__info__]

    docs
    |> Enum.filter(fn
      {{:function, name, _arity}, _, _, _, _} ->
        name_str = Atom.to_string(name)
        not String.starts_with?(name_str, "_") and
          name not in lua_api_functions and
          (is_nil(only) or name in only) and
          name not in except

      _ ->
        false
    end)
  end

  defp find_function_doc(docs, func_name) do
    Enum.find(docs, fn
      {{:function, ^func_name, _arity}, _, _, _, _} -> true
      _ -> false
    end)
  end

  defp build_tool_from_doc(module, {{:function, name, arity}, _, signatures, doc, _meta}, opts) do
    tool_name = build_tool_name(name, opts)
    description = extract_description(doc)

    spec_types = extract_spec_types(module, name, arity)
    opts_with_specs = merge_spec_types(opts, spec_types)

    parameters = extract_parameters(signatures, arity, opts_with_specs, doc)

    tool = new(tool_name, description, parameters, module)
    {name, tool}
  end

  defp build_tool_name(func_name, opts) do
    custom_name = Keyword.get(opts, :as)
    prefix = Keyword.get(opts, :prefix, "")

    cond do
      custom_name -> custom_name
      prefix != "" -> "#{prefix}#{func_name}"
      true -> Atom.to_string(func_name)
    end
  end

  defp extract_description(%{"en" => doc_text}) when is_binary(doc_text) do
    doc_text
    |> String.split("\n\n", parts: 2)
    |> List.first()
    |> String.trim()
  end

  defp extract_description(_), do: ""

  defp extract_parameters([signature | _], arity, opts, doc) when is_binary(signature) do
    param_types_override = Keyword.get(opts, :param_types, %{})
    spec_types_by_pos = Keyword.get(opts, :__spec_types__, %{})

    params =
      signature
      |> extract_param_names()
      |> Enum.take(arity)

    param_metadata = parse_param_metadata(doc)

    params
    |> Enum.with_index()
    |> Enum.map(fn {{param_name, has_default}, index} ->
      param_atom = String.to_atom(param_name)
      metadata = Map.get(param_metadata, param_name, %{})

      param_type =
        Map.get(param_types_override, param_atom) ||
          Map.get(metadata, :type) ||
          Map.get(spec_types_by_pos, index) ||
          :string

      %{
        name: param_name,
        type: param_type,
        description: Map.get(metadata, :description, ""),
        required: not has_default
      }
    end)
  end

  defp extract_parameters([signature | _], arity, opts, doc) do
    extract_parameters([signature], arity, opts, doc)
  end

  defp extract_parameters(_, arity, opts, _doc) do
    param_types = Keyword.get(opts, :param_types, %{})

    Enum.map(1..arity, fn i ->
      param_name = "arg#{i}"
      param_atom = String.to_atom(param_name)
      param_type = Map.get(param_types, param_atom, :string)

      %{
        name: param_name,
        type: param_type,
        description: "",
        required: true
      }
    end)
  end

  # Parse parameter metadata from @doc ## Parameters section
  # Supports formats:
  #   - param_name: Description text
  #   - param_name [type]: Description text
  #   - param_name (type): Description text
  defp parse_param_metadata(%{"en" => doc_text}) when is_binary(doc_text) do
    case extract_parameters_section(doc_text) do
      nil ->
        %{}

      params_section ->
        params_section
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&String.starts_with?(&1, "-"))
        |> Enum.map(&parse_param_line/1)
        |> Enum.reject(&is_nil/1)
        |> Map.new()
    end
  end

  defp parse_param_metadata(_), do: %{}

  defp extract_parameters_section(doc_text) do
    case Regex.run(~r/## Parameters\s*\n(.*?)(?=\n##|\z)/s, doc_text) do
      [_, params_text] -> params_text
      _ -> nil
    end
  end

  # Parse a single parameter line
  # Examples:
  #   "- string: The string to match"
  #   "- pattern [string]: The regex pattern"
  #   "- count (number): The count value"
  defp parse_param_line(line) do
    regex = ~r/^\s*-\s+(\w+)(?:\s*[\[\(](\w+)[\]\)])?\s*:\s*(.+)$/

    case Regex.run(regex, line) do
      [_, name, "", description] ->
        {name, %{description: String.trim(description)}}

      [_, name, type_str, description] ->
        type = parse_type_string(type_str)
        {name, %{description: String.trim(description), type: type}}

      _ ->
        nil
    end
  end

  defp parse_type_string(type_str) do
    normalized = String.downcase(type_str)

    cond do
      normalized == "string" -> :string
      normalized == "number" -> :number
      normalized in ["boolean", "bool"] -> :boolean
      normalized in ["table", "list", "array", "map"] -> :table
      true -> :string
    end
  end

  defp extract_spec_types(module, func_name, arity) do
    with {:ok, specs} <- Code.Typespec.fetch_specs(module),
         spec when not is_nil(spec) <- find_matching_spec(specs, func_name, arity) do
      spec
    else
      _ -> %{}
    end
  end

  defp find_matching_spec(specs, func_name, arity) do
    Enum.find_value(specs, fn
      {{^func_name, ^arity}, spec_list} ->
        extract_param_types_from_spec(spec_list)

      _ ->
        nil
    end)
  end

  defp extract_param_types_from_spec(spec_list) do
    case spec_list do
      [{:type, _, :fun, [{:type, _, :product, param_types}, _return_type]} | _] ->
        param_types
        |> Enum.with_index()
        |> Map.new(fn {type_ast, index} ->
          {index, typespec_to_atom(type_ast)}
        end)

      _ ->
        nil
    end
  end

  defp merge_spec_types(opts, spec_types) when map_size(spec_types) == 0 do
    opts
  end

  defp merge_spec_types(opts, spec_types) do
    Keyword.put(opts, :__spec_types__, spec_types)
  end

  defp typespec_to_atom({:type, _, :binary, []}), do: :string
  defp typespec_to_atom({:type, _, :bitstring, []}), do: :string
  defp typespec_to_atom({:remote_type, _, [{:atom, _, String}, {:atom, _, :t}, []]}), do: :string

  defp typespec_to_atom({:type, _, :integer, []}), do: :number
  defp typespec_to_atom({:type, _, :float, []}), do: :number
  defp typespec_to_atom({:type, _, :number, []}), do: :number

  defp typespec_to_atom({:type, _, :boolean, []}), do: :boolean

  defp typespec_to_atom({:type, _, :list, _}), do: :table
  defp typespec_to_atom({:type, _, :map, _}), do: :table
  defp typespec_to_atom({:type, _, :tuple, _}), do: :table

  defp typespec_to_atom({:user_type, _, :table, []}), do: :table

  defp typespec_to_atom(_), do: :string

  defp extract_param_names(signature) do
    case Regex.run(~r/\(([^)]*)\)/, signature) do
      [_, params_str] when params_str != "" ->
        params_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(fn param ->
          has_default = String.contains?(param, "\\\\")

          name =
            param
            |> String.split(["\\\\", " "])
            |> List.first()
            |> String.trim()

          {name, has_default}
        end)

      _ ->
        []
    end
  end
end
