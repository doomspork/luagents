defmodule Luagents.Test.TypeAnnotationTools do
  @moduledoc """
  Test tools for type annotation extraction.
  """

  use Lua.API

  @doc """
  Process data with type annotations.

  ## Parameters
    - name [string]: The name value
    - count [number]: The count value
    - enabled [boolean]: Whether enabled
    - data [table]: The data structure
  """
  deflua process(name, count, enabled, data) do
    {:ok, {name, count, enabled, data}}
  end

  @doc """
  Test parentheses annotations.

  ## Parameters
    - value (number): A numeric value
    - items (table): A list of items
  """
  deflua test_parens(value, items) do
    {:ok, {value, items}}
  end
end
