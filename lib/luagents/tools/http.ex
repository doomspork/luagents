defmodule Luagents.Tools.Http do
  @moduledoc """
  HTTP client tool for Lua agents.

  Provides functions to make HTTP requests (GET, POST, PUT, DELETE) using Req.
  """

  use Luagents.API, scope: "http"

  @doc """
  Make a GET request to the specified URL.

  ## Parameters
    - url [string]: The URL to request
    - headers [table]: Optional table of headers (default: {})

  ## Returns
    - Lua table {status, headers, body} on success
    - Error string on failure

  ## Examples

      iex> Luagents.Tools.Http.get("https://api.github.com")
      {200, %{}, body}
  """
  deflua get(url, headers \\ %{}), state do
    request(:get, url, headers, nil, state)
  end

  @doc """
  Make a POST request to the specified URL.

  ## Parameters
    - url [string]: The URL to request
    - body [string|table]: The request body (string or table)
    - headers [table]: Optional table of headers (default: {})

  ## Returns
    - Lua table {status, headers, body} on success
    - Error string on failure
  """
  deflua post(url, body, headers \\ %{}), state do
    request(:post, url, headers, body, state)
  end

  @doc """
  Make a PUT request to the specified URL.

  ## Parameters
    - url [string]: The URL to request
    - body [string|table]: The request body (string or table)
    - headers [table]: Optional table of headers (default: {})

  ## Returns
    - Lua table {status, headers, body} on success
    - Error string on failure
  """
  deflua put(url, body, headers \\ %{}), state do
    request(:put, url, headers, body, state)
  end

  @doc """
  Make a DELETE request to the specified URL.

  ## Parameters
    - url [string]: The URL to request
    - headers [table]: Optional table of headers (default: {})

  ## Returns
    - Lua table {status, headers, body} on success
    - Error string on failure
  """
  deflua delete(url, headers \\ %{}), state do
    request(:delete, url, headers, nil, state)
  end

  defp request(method, url, headers, body, state) do
    options =
      [method: method, url: url]
      |> add_headers_to_options(headers, state)
      |> add_body_to_options(body, state)

    execute_request(options, state)
  end

  defp add_headers_to_options(options, headers, state) do
    headers_decoded = decode_lua_headers(headers, state)

    if has_headers?(headers_decoded) do
      Keyword.put(options, :headers, headers_decoded)
    else
      options
    end
  end

  defp add_body_to_options(options, nil, _state), do: options

  defp add_body_to_options(options, body, state) do
    body_decoded = decode_lua_body(body, state)
    body_data = encode_body_if_needed(body_decoded)
    Keyword.put(options, :body, body_data)
  end

  defp decode_lua_headers(headers, state) do
    decoded = safe_lua_decode(state, headers, headers)
    convert_list_to_map_if_needed(decoded)
  end

  defp decode_lua_body(body, state) do
    decoded = safe_lua_decode(state, body, body)
    convert_lua_table_to_elixir(decoded)
  end

  defp safe_lua_decode(state, value, default) do
    Lua.decode!(state, value)
  rescue
    _ -> default
  end

  defp convert_list_to_map_if_needed(list) when is_list(list) and list != [] do
    Map.new(list)
  end

  defp convert_list_to_map_if_needed(value), do: value

  defp convert_lua_table_to_elixir(list) when is_list(list) and list != [] do
    if Enum.all?(list, &is_tuple/1) do
      Map.new(list)
    else
      list
    end
  end

  defp convert_lua_table_to_elixir(value), do: value

  defp has_headers?(headers) do
    headers != %{} and is_map(headers) and map_size(headers) > 0
  end

  defp execute_request(options, state) do
    case Req.request(options) do
      {:ok, response} -> format_success_response(response, state)
      {:error, error} -> "HTTP request failed: #{inspect(error)}"
    end
  rescue
    error -> "HTTP request failed: #{Exception.message(error)}"
  catch
    :exit, reason -> "HTTP request failed: #{inspect(reason)}"
  end

  defp format_success_response(%Req.Response{status: status, headers: headers, body: body}, state) do
    headers_simple = simplify_headers(headers)
    body_string = ensure_body_is_string(body)
    result_list = [status, headers_simple, body_string]
    Lua.encode!(state, result_list)
  end

  defp simplify_headers(headers) do
    headers
    |> Enum.map(fn {k, v} ->
      simple_value = if is_list(v), do: List.first(v), else: v
      {k, simple_value}
    end)
    |> Map.new()
  end

  defp ensure_body_is_string(body) when is_binary(body), do: body

  defp ensure_body_is_string(body) when is_map(body) or is_list(body) do
    case Jason.encode(body) do
      {:ok, json} -> json
      {:error, _} -> inspect(body)
    end
  end

  defp ensure_body_is_string(body), do: to_string(body)

  defp encode_body_if_needed(body) when is_map(body) do
    case Jason.encode(body) do
      {:ok, json} -> json
      {:error, _} -> body
    end
  end

  defp encode_body_if_needed(body), do: body
end
