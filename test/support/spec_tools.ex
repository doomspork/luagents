defmodule Luagents.Test.SpecTools do
  @moduledoc """
  Test tools for @spec type extraction.
  """

  use Lua.API

  @doc "Add two numbers"
  @spec add(integer(), integer()) :: {:ok, integer()}
  deflua add(a, b) do
    {:ok, a + b}
  end

  @doc "Concatenate strings"
  @spec concat(String.t(), String.t()) :: {:ok, String.t()}
  deflua concat(s1, s2) do
    {:ok, s1 <> s2}
  end

  @doc "Check if two values are equal"
  @spec equal?(boolean(), boolean()) :: {:ok, boolean()}
  deflua equal?(a, b) do
    {:ok, a == b}
  end

  @doc "Process a list"
  @spec process_list(list()) :: {:ok, list()}
  deflua process_list(items) do
    {:ok, items}
  end
end
