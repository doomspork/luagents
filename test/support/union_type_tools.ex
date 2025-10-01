defmodule Luagents.Test.UnionTypeTools do
  @moduledoc """
  Test tools for union type annotations.
  """

  use Lua.API

  @doc """
  Test union types with square brackets.

  ## Parameters
    - body [string|table]: The request body (string or table)
    - data [number|string]: Numeric or string data
  """
  deflua test_union_brackets(body, data) do
    {:ok, {body, data}}
  end

  @doc """
  Test union types with parentheses.

  ## Parameters
    - value (number|boolean): A value that can be number or boolean
    - input (string|table|number): Multi-type input
  """
  deflua test_union_parens(value, input) do
    {:ok, {value, input}}
  end

  @doc """
  Test single type still works.

  ## Parameters
    - name [string]: Just a string
    - count [number]: Just a number
  """
  deflua test_single_type(name, count) do
    {:ok, {name, count}}
  end

  @doc """
  Test complex union types.

  ## Parameters
    - config [string|table|boolean]: Configuration value
    - items [table|string]: Collection or serialized data
  """
  deflua test_complex_union(config, items) do
    {:ok, {config, items}}
  end
end
