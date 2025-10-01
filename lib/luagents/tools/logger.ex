defmodule Luagents.Tools.Logger do
  @moduledoc """
  Logger tool for Lua agents.

  Provides functions to log messages to the Elixir Logger at various levels.

  ## Usage

      tools = Tool.from_module(Luagents.Tools.Logger)

  ## Lua Usage

      log.debug("Debug information")
      log.info("Information message")
      log.warning("Warning message")
      log.error("Error message")
      log.log("info", "User action", {user_id = 123})
  """

  use Luagents.API, scope: "log"

  require Logger

  @doc """
  Log a debug message.

  ## Parameters
    - message [string]: The message to log

  ## Examples

      iex> Luagents.Tools.Logger.debug("Debug information")
      nil
  """
  deflua debug(message, metadata \\ %{}) do
    Logger.debug(to_string(message), metadata)
    nil
  end

  @doc """
  Log an info message.

  ## Parameters
    - message [string]: The message to log

  ## Examples

      iex> Luagents.Tools.Logger.info("Information message")
      nil
  """
  deflua info(message, metadata \\ %{}) do
    Logger.info(to_string(message), metadata)
    nil
  end

  @doc """
  Log a warning message.

  ## Parameters
    - message [string]: The message to log

  ## Examples

      iex> Luagents.Tools.Logger.warning("Warning message")
      nil
  """
  deflua warning(message, metadata \\ %{}) do
    Logger.warning(to_string(message), metadata)
    nil
  end

  @doc """
  Log an error message.

  ## Parameters
    - message [string]: The message to log

  ## Examples

      iex> Luagents.Tools.Logger.error("Error message")
      nil
  """
  deflua error(message, metadata \\ %{}) do
    Logger.error(to_string(message), metadata)
    nil
  end

  @doc """
  Log a message with metadata.

  ## Parameters
    - level [string]: The log level (debug, info, warning, error)
    - message [string]: The message to log
    - metadata [table]: Additional metadata as key-value pairs

  ## Examples

      iex> Luagents.Tools.Logger.log("info", "User action", %{"user_id" => 123})
      nil
  """
  deflua log(level, message, metadata \\ %{}) do
    level_atom = parse_level(level)
    metadata_keyword = map_to_keyword(metadata)

    Logger.log(level_atom, to_string(message), metadata_keyword)
    nil
  end

  defp parse_level(level) when is_binary(level) do
    case String.downcase(level) do
      "debug" -> :debug
      "info" -> :info
      "warning" -> :warning
      "warn" -> :warning
      "error" -> :error
      _ -> :info
    end
  end

  defp parse_level(level) when is_atom(level), do: level
  defp parse_level(_), do: :info

  defp map_to_keyword(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      key = if is_atom(k), do: k, else: String.to_atom(to_string(k))
      {key, v}
    end)
  end

  defp map_to_keyword(_), do: []
end
