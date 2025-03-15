defmodule LuaAgentsTest do
  use ExUnit.Case
  doctest LuaAgents

  test "greets the world" do
    assert LuaAgents.hello() == :world
  end
end
