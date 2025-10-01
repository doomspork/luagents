defmodule Luagents.Test.PriorityTools do
  @moduledoc """
  Test tools for type priority resolution.
  """

  use Luagents.API

  @doc """
  Test type priority.

  ## Parameters
    - param1 [number]: First parameter with @doc type
    - param2: Second parameter with no @doc type

  """
  @spec test_priority(integer(), String.t()) :: {:ok, {integer(), String.t()}}
  deflua test_priority(param1, param2) do
    {:ok, {param1, param2}}
  end
end
