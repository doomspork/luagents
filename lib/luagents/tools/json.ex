defmodule Luagents.Tools.Json do
  @moduledoc """
  JSON parsing and encoding tool for Lua agents.

  Provides functions to parse JSON strings into Lua tables and encode
  Lua tables/values back to JSON strings.

  All functions return the result directly (not wrapped in tuples) for
  Lua compatibility. Returns nil on error.
  """

  use Lua.API

  @doc """
  Parse a JSON string into a Lua table.

  Returns the parsed data on success, or nil on error.

  ## Parameters
    - json_string [string]: The JSON string to parse

  ## Examples

      iex> Luagents.Tools.Json.parse(~s({"name": "Alice", "age": 30}))
      %{"name" => "Alice", "age" => 30}

      iex> Luagents.Tools.Json.parse("invalid json")
      nil
  """
  deflua parse(json_string), state do
    case Jason.decode(json_string) do
      {:ok, data} when is_map(data) or is_list(data) -> Lua.encode!(state, data)
      {:ok, data} -> data
      {:error, _error} -> nil
    end
  end

  @doc """
  Encode a Lua table/value into a JSON string.

  Returns the JSON string on success, or nil on error.

  ## Parameters
    - data [table]: The Lua table or value to encode

  ## Examples

      iex> Luagents.Tools.Json.encode(%{"name" => "Alice", "age" => 30})
      ~s({"age":30,"name":"Alice"})

      iex> Luagents.Tools.Json.encode([1, 2, 3])
      "[1,2,3]"
  """
  deflua encode(data), state do
    try do
      decoded_data = Lua.decode!(state, data)
      converted_data = convert_lua_table(decoded_data)

      case Jason.encode(converted_data) do
        {:ok, json} -> json
        {:error, _error} -> nil
      end
    rescue
      _ -> nil
    end
  end

  @doc """
  Pretty-print encode a Lua table/value into a formatted JSON string.

  Returns the formatted JSON string on success, or nil on error.

  ## Parameters
    - data [table]: The Lua table or value to encode

  ## Examples

      iex> Luagents.Tools.Json.pretty(%{"name" => "Alice"})
      "{\\n  \\\"name\\\": \\\"Alice\\\"\\n}"
  """
  deflua pretty(data), state do
    try do
      decoded_data = Lua.decode!(state, data)
      converted_data = convert_lua_table(decoded_data)

      case Jason.encode(converted_data, pretty: true) do
        {:ok, json} -> json
        {:error, _error} -> nil
      end
    rescue
      _ -> nil
    end
  end

  defp convert_lua_table(data) when is_list(data) do
    if Enum.all?(data, fn {k, _v} -> is_integer(k) end) and
         Enum.sort_by(data, fn {k, _v} -> k end) ==
           Enum.with_index(data, 1) |> Enum.map(fn {{_, v}, i} -> {i, v} end) do
      data
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {_k, v} -> convert_lua_table(v) end)
    else
      data
      |> Enum.map(fn {k, v} -> {to_string(k), convert_lua_table(v)} end)
      |> Map.new()
    end
  end

  defp convert_lua_table(data), do: data
end
