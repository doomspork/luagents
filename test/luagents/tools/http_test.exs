defmodule Luagents.Tools.HttpTest do
  use ExUnit.Case, async: false

  import Luagents.Test.LuaToolTestHelper

  alias Luagents.Tool
  alias Luagents.Tools.Http

  setup do
    bypass = Bypass.open()
    tools = Tool.from_module(Http, prefix: "http_")
    lua = setup_lua_with_tools(tools)
    {:ok, bypass: bypass, lua: lua}
  end

  describe "http_get/2" do
    test "makes successful GET request from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "GET", "/posts/1", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"userId": 1, "id": 1, "title": "Test Post"}))
      end)

      code = """
      local status, headers, body = table.unpack(http_get("http://localhost:#{bypass.port}/posts/1"))
      if status == 200 and body then
        local found = string.find(body, "userId")
        if found then
          return "ok"
        end
      end
      """

      result = eval_lua(lua, code)
      assert result == "ok"
    end

    test "GET request returns valid JSON data from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "GET", "/users/1", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"name": "Leanne Graham", "email": "test@example.com"}))
      end)

      code = """
      local status, headers, body = table.unpack(http_get("http://localhost:#{bypass.port}/users/1"))
      if status == 200 then
        local found = string.find(body, "Leanne Graham")
        if found then
          return "found"
        end
      end
      """

      result = eval_lua(lua, code)
      assert result == "found"
    end

    test "GET request with custom headers from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "GET", "/posts/1", fn conn ->
        assert Plug.Conn.get_req_header(conn, "user-agent") == ["Luagents/Test"]
        Plug.Conn.resp(conn, 200, ~s({"id": 1}))
      end)

      code = """
      local headers = {["User-Agent"] = "Luagents/Test"}
      local status, resp_headers, body = table.unpack(http_get("http://localhost:#{bypass.port}/posts/1", headers))
      return status
      """

      result = eval_lua(lua, code)
      assert result == 200
    end

    test "GET request to 404 endpoint from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "GET", "/posts/999999", fn conn ->
        Plug.Conn.resp(conn, 404, ~s({"error": "Not found"}))
      end)

      code = """
      local status, headers, body = table.unpack(http_get("http://localhost:#{bypass.port}/posts/999999"))
      return status
      """

      result = eval_lua(lua, code)
      assert result == 404
    end

    test "handles GET request errors from Lua", %{lua: lua} do
      code = """
      local result = http_get("not-a-valid-url")
      if type(result) == "string" then
        local found = string.find(result, "HTTP request failed")
        if found then
          return "error"
        end
      end
      """

      result = eval_lua(lua, code)
      assert result == "error"
    end
  end

  describe "http_post/3" do
    test "makes successful POST request with JSON body from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "POST", "/posts", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert String.contains?(body, "Test Post")
        Plug.Conn.resp(conn, 201, body)
      end)

      code = """
      local body = {title = "Test Post", body = "Test content", userId = 1}
      local headers = {["Content-Type"] = "application/json"}
      local status, resp_headers, resp_body = table.unpack(http_post("http://localhost:#{bypass.port}/posts", body, headers))
      if status == 201 and resp_body then
        local found = string.find(resp_body, "Test Post")
        if found then
          return "ok"
        end
      end
      """

      result = eval_lua(lua, code)
      assert result == "ok"
    end

    test "POST request returns created resource from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "POST", "/posts", fn conn ->
        Plug.Conn.resp(conn, 201, ~s({"id": 101}))
      end)

      code = """
      local body = {name = "Alice", email = "alice@example.com"}
      local status, headers, resp = table.unpack(http_post("http://localhost:#{bypass.port}/posts", body, {}))
      return status
      """

      result = eval_lua(lua, code)
      assert result == 201
    end

    test "POST request with string body from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "POST", "/posts", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == "plain text data"
        Plug.Conn.resp(conn, 201, ~s({"received": "ok"}))
      end)

      code = """
      local body = "plain text data"
      local status, headers, resp = table.unpack(http_post("http://localhost:#{bypass.port}/posts", body, {}))
      if status == 201 then
        return "ok"
      end
      """

      result = eval_lua(lua, code)
      assert result == "ok"
    end
  end

  describe "http_put/3" do
    test "makes successful PUT request from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "PUT", "/posts/1", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert String.contains?(body, "Updated")
        Plug.Conn.resp(conn, 200, body)
      end)

      code = """
      local body = {id = 1, title = "Updated", body = "Updated content", userId = 1}
      local headers = {["Content-Type"] = "application/json"}
      local status, resp_headers, resp_body = table.unpack(http_put("http://localhost:#{bypass.port}/posts/1", body, headers))
      if status == 200 and resp_body then
        local found = string.find(resp_body, "Updated")
        if found then
          return "ok"
        end
      end
      """

      result = eval_lua(lua, code)
      assert result == "ok"
    end

    test "PUT request updates resource from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "PUT", "/users/1", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"name": "Bob Updated"}))
      end)

      code = """
      local body = {name = "Bob Updated"}
      local status = table.unpack(http_put("http://localhost:#{bypass.port}/users/1", body, {}))
      return status
      """

      result = eval_lua(lua, code)
      assert result == 200
    end
  end

  describe "http_delete/2" do
    test "makes successful DELETE request from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "DELETE", "/posts/1", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({}))
      end)

      code = """
      local status, headers, body = table.unpack(http_delete("http://localhost:#{bypass.port}/posts/1"))
      return status
      """

      result = eval_lua(lua, code)
      assert result == 200
    end

    test "DELETE request with custom headers from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "DELETE", "/posts/1", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token123"]
        Plug.Conn.resp(conn, 200, ~s({}))
      end)

      code = """
      local headers = {["Authorization"] = "Bearer token123"}
      local status = table.unpack(http_delete("http://localhost:#{bypass.port}/posts/1", headers))
      return status
      """

      result = eval_lua(lua, code)
      assert result == 200
    end

    test "DELETE request removes resource from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "DELETE", "/users/1", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({}))
      end)

      code = """
      local status, headers, body = table.unpack(http_delete("http://localhost:#{bypass.port}/users/1"))
      if status == 200 then
        return "deleted"
      end
      """

      result = eval_lua(lua, code)
      assert result == "deleted"
    end
  end

  describe "error handling" do
    test "returns error for invalid URL from Lua", %{lua: lua} do
      code = """
      local result = http_get("not-a-valid-url")
      if type(result) == "string" then
        local found = string.find(result, "HTTP request failed")
        if found then
          return "error"
        end
      end
      """

      result = eval_lua(lua, code)
      assert result == "error"
    end

    test "handles network errors gracefully from Lua", %{lua: lua} do
      code = """
      local result = http_get("http://localhost:99999")
      if type(result) == "string" then
        return "error"
      end
      """

      result = eval_lua(lua, code)
      assert result == "error"
    end

    test "handles connection refused errors from Lua", %{lua: lua} do
      code = """
      local result = http_get("http://localhost:1")
      if type(result) == "string" then
        local found = string.find(result, "HTTP request failed")
        if found then
          return "error"
        end
      end
      """

      result = eval_lua(lua, code)
      assert result == "error"
    end
  end

  describe "integration scenarios" do
    test "fetch and parse JSON response in Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect_once(bypass, "GET", "/posts/1", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"userId": 1, "id": 1, "title": "Test"}))
      end)

      code = """
      local status, headers, body = table.unpack(http_get("http://localhost:#{bypass.port}/posts/1"))
      if status == 200 then
        -- Simulate parsing - in real usage would use json_parse
        local found_user = string.find(body, '"userId"')
        local found_id = string.find(body, '"id"')
        if found_user and found_id then
          return "parsed"
        end
      end
      """

      result = eval_lua(lua, code)
      assert result == "parsed"
    end

    test "make multiple requests in sequence from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect(bypass, "GET", "/posts/1", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"id": 1}))
      end)

      Bypass.expect(bypass, "GET", "/posts/2", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"id": 2}))
      end)

      Bypass.expect(bypass, "GET", "/posts/3", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"id": 3}))
      end)

      code = """
      local count = 0
      for i = 1, 3 do
        local status = table.unpack(http_get("http://localhost:#{bypass.port}/posts/" .. i))
        if status == 200 then
          count = count + 1
        end
      end
      return count
      """

      result = eval_lua(lua, code)
      assert result == 3
    end

    test "conditional requests based on response from Lua", %{bypass: bypass, lua: lua} do
      Bypass.expect(bypass, "GET", "/posts/1", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"id": 1}))
      end)

      Bypass.expect(bypass, "GET", "/users/1", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"id": 1, "name": "Test User"}))
      end)

      code = """
      local status, headers, body = table.unpack(http_get("http://localhost:#{bypass.port}/posts/1"))
      if status == 200 then
        -- Make another request based on first response
        local status2 = table.unpack(http_get("http://localhost:#{bypass.port}/users/1"))
        if status2 == 200 then
          return "success"
        end
      end
      """

      result = eval_lua(lua, code)
      assert result == "success"
    end
  end
end
