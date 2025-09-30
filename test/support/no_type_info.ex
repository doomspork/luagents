defmodule Luagents.Test.NoTypeInfo do
  @moduledoc """
  Test tools with no type information.
  """

  use Lua.API

  @doc "Function with no type info"
  deflua no_info(param) do
    {:ok, param}
  end
end
