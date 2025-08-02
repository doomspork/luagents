defmodule LuagentsTest do
  use ExUnit.Case
  doctest Luagents

  test "builtin tools are available" do
    tools = Luagents.builtin_tools()
    assert is_map(tools)
    assert Map.has_key?(tools, "add")
  end
end
