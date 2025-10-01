defmodule Luagents.Test.AltTypeTools do
  @moduledoc """
  Test tools for alternative type names.
  """

  use Luagents.API

  @doc """
  Test alternative type names.

  ## Parameters
    - items [list]: A list of items
    - mapping [map]: A map of values
    - collection [array]: An array
  """
  deflua test_alt(items, mapping, collection) do
    {:ok, {items, mapping, collection}}
  end
end
