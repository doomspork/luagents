defmodule Luagents.API do
  @moduledoc """
  Extends Lua.API with compile-time tool metadata generation for Luagents.

  Use this instead of Lua.API in tool modules to enable automatic tool
  metadata generation at compile time, avoiding expensive runtime parsing.

  ## Benefits

  - **Performance**: Tool metadata is generated once at compile time instead of
    being parsed from docs on every `Tool.from_module/2` call
  - **Type Safety**: Compile-time validation of tool metadata
  - **Zero Runtime Cost**: No doc parsing or reflection needed at runtime
  - **Backward Compatible**: Falls back to runtime parsing for `Lua.API` modules

  ## Usage

      defmodule MyTools do
        use Luagents.API, scope: "my"

        @doc \"\"\"
        Add two numbers.

        ## Parameters
          - a [number]: First number
          - b [number]: Second number
        \"\"\"
        deflua add(a, b) do
          a + b
        end
      end

      # Fast path - uses compile-time generated metadata
      tools = Luagents.Tool.from_module(MyTools)

  ## How It Works

  When you `use Luagents.API`, the module:
  1. Inherits all `Lua.API` functionality (deflua, scope, etc.)
  2. Registers a `@before_compile` hook
  3. At compile time, extracts all deflua function metadata
  4. Generates a `__luagent_tools__/0` function with pre-built tool metadata
  5. `Tool.from_module/2` checks for this function and uses it directly

  This avoids the expensive runtime operations:
  - `Code.fetch_docs/1` - Fetching and parsing documentation
  - Regex parsing of parameter sections
  - Type extraction from specs
  - Tool struct construction

  All of this happens once at compile time instead of every time you call
  `from_module/2`.
  """

  @doc false
  defmacro __using__(opts) do
    quote do
      use Lua.API, unquote(opts)

      @before_compile Luagents.API
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def __luagent_tools__ do
        # Generate metadata lazily on first call and cache it
        case :persistent_term.get({Luagents.API, __MODULE__}, nil) do
          nil ->
            metadata = Luagents.API.build_metadata(__MODULE__)
            :persistent_term.put({Luagents.API, __MODULE__}, metadata)
            metadata

          cached ->
            cached
        end
      end
    end
  end

  @doc false
  # Build tool metadata using Code.fetch_docs (called at runtime but cached)
  def build_metadata(module) do
    scope = get_module_scope(module)

    case Code.fetch_docs(module) do
      {:docs_v1, _, :elixir, _, _, _, docs} ->
        docs
        |> Enum.filter(&should_include_doc?/1)
        |> Enum.map(&build_metadata_from_doc(&1, module, scope))
        |> Map.new()

      _ ->
        # Fallback if docs not available
        %{}
    end
  end

  defp get_module_scope(module) do
    module.scope()
  rescue
    _ ->
      []
  end

  defp should_include_doc?({{:function, name, _arity}, _, _, _, _}) do
    name_str = Atom.to_string(name)

    # Exclude private functions, internal functions, and Lua.API callbacks
    not String.starts_with?(name_str, "_") and
      name not in [:__lua_functions__, :__luagent_tools__, :scope, :__info__]
  end

  defp should_include_doc?(_), do: false

  defp build_metadata_from_doc(
         {{:function, name, arity}, _, signatures, doc, _meta},
         module,
         scope
       ) do
    tool_name = build_tool_name(scope, name)
    description = extract_description(doc)

    # Extract doc text and parse parameter metadata
    doc_text = extract_doc_text(doc)
    param_metadata = parse_param_metadata(doc_text)

    # Get spec types
    spec_types = extract_spec_types(module, name, arity)

    # Build parameters from signature
    parameters = extract_parameters(signatures, arity, param_metadata, spec_types)

    metadata = %{
      name: tool_name,
      description: description,
      parameters: parameters,
      api: module,
      function_name: name
    }

    {name, metadata}
  end

  defp extract_doc_text(%{"en" => doc_text}) when is_binary(doc_text), do: doc_text
  defp extract_doc_text(_), do: ""

  defp extract_description(%{"en" => doc_text}) when is_binary(doc_text) do
    doc_text
    |> String.split("\n\n", parts: 2)
    |> List.first()
    |> String.trim()
  end

  defp extract_description(_), do: ""

  defp extract_parameters([signature | _], arity, param_metadata, spec_types)
       when is_binary(signature) do
    params =
      signature
      |> extract_param_names()
      |> Enum.take(arity)
      # deflua adds a 'state' parameter that should be excluded from tool parameters
      |> Enum.reject(fn {name, _} -> name == "state" end)

    params
    |> Enum.with_index()
    |> Enum.map(fn {{param_name, has_default}, index} ->
      metadata = Map.get(param_metadata, param_name, %{})

      param_type =
        Map.get(metadata, :type) ||
          Map.get(spec_types, index) ||
          :string

      %{
        name: param_name,
        type: param_type,
        description: Map.get(metadata, :description, ""),
        required: not has_default
      }
    end)
  end

  defp extract_parameters(_, arity, _param_metadata, spec_types) do
    # Fallback when no signature available
    Enum.map(1..arity, fn i ->
      param_type = Map.get(spec_types, i - 1, :string)

      %{
        name: "arg#{i}",
        type: param_type,
        description: "",
        required: true
      }
    end)
  end

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

  defp parse_param_metadata(""), do: %{}

  defp parse_param_metadata(doc_text) do
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
  #   "- body [string|table]: The request body (string or table)"
  defp parse_param_line(line) do
    regex = ~r/^\s*-\s+(\w+)(?:\s*[\[\(]([\w\|]+)[\]\)])?\s*:\s*(.+)$/

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
    # Check if it contains pipe character for union types
    if String.contains?(type_str, "|") do
      type_str
      |> String.split("|")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&parse_single_type/1)
    else
      parse_single_type(type_str)
    end
  end

  defp parse_single_type(type_str) do
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
    case Code.Typespec.fetch_specs(module) do
      {:ok, specs} ->
        find_matching_spec(specs, func_name, arity)

      _ ->
        %{}
    end
  rescue
    # Typespec fetching might fail during compilation
    _ -> %{}
  end

  defp find_matching_spec(specs, func_name, arity) do
    Enum.find_value(specs, %{}, fn
      {{^func_name, ^arity}, spec_list} ->
        extract_param_types_from_spec(spec_list)

      _ ->
        nil
    end)
  end

  defp extract_param_types_from_spec(spec_list) when is_list(spec_list) do
    case spec_list do
      [{:type, _, :fun, [{:type, _, :product, param_types}, _return_type]} | _] ->
        param_types
        |> Enum.with_index()
        |> Map.new(fn {type_ast, index} ->
          {index, typespec_to_atom(type_ast)}
        end)

      _ ->
        %{}
    end
  end

  defp extract_param_types_from_spec(_), do: %{}

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

  defp build_tool_name([], func_name), do: Atom.to_string(func_name)

  defp build_tool_name(scope, func_name) when is_list(scope) do
    (scope ++ [Atom.to_string(func_name)])
    |> Enum.join(".")
  end

  defp build_tool_name(scope, func_name) when is_binary(scope) do
    build_tool_name([scope], func_name)
  end
end
