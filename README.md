# Luagents

[![Continuous Integration](https://github.com/doomspork/luagents/actions/workflows/ci.yml/badge.svg)](https://github.com/doomspork/luagents/actions/workflows/ci.yaml)
[![Module Version](https://img.shields.io/hexpm/v/luagents.svg)](https://hex.pm/packages/luagents)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/luagents/)
[![Total Download](https://img.shields.io/hexpm/dt/luagents.svg)](https://hex.pm/packages/luagents)
[![License](https://img.shields.io/hexpm/l/luagents.svg)](https://github.com/doomspork/luagents/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/doomspork/luagents.svg)](https://github.com/doomspork/luagents/commits/main)

A ReAct (Reasoning and Acting) agent implementation in Elixir that thinks using Lua code. Inspired by [smolagents](https://github.com/huggingface/smolagents).

## Overview

Luagents implements a ReAct loop where:
1. The agent receives a task from the user
2. It uses an LLM (Large Language Model) to generate Lua code to think through the problem step-by-step
3. The Lua code can call tools and reason about results
4. The agent continues until it finds a final answer

## Supported LLM Providers

Luagents supports multiple LLM providers through a pluggable architecture:

- **Anthropic Claude** (via Anthropix) - Cloud-based, high-quality responses
- **Ollama** - Local models, privacy-focused, customizable

**Important Note**: This agent's performance is directly tied to the quality of the underlying language model. Using a model with strong reasoning and coding capabilities is essential for reliable results.

## Installation

Add `luagents` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:luagents, "~> 0.1.0"}
  ]
end
```

## Configuration

### Anthropic Claude

Set your Anthropic API key using one of these methods:

1. Environment variable (recommended):
```bash
export ANTHROPIC_API_KEY=your-api-key
```

2. Pass directly when creating an agent:
```elixir
agent = Luagents.Agent.new(
  llm: Luagents.LLM.new(provider: :anthropic, api_key: "your-api-key")
)
```

### Ollama

1. Install and run [Ollama](https://ollama.com/)
2. Pull a model (e.g., `ollama pull mistral`)
3. Create an agent with Ollama provider:

```elixir
agent = Luagents.Agent.new(
  llm: Luagents.LLM.new(provider: :ollama, model: "mistral")
)
```

## Usage

### Basic Usage

```elixir
# Create an agent (uses Anthropic Claude by default)
agent = Luagents.create_agent(name: "MyBot")

# Run a task
{:ok, result} = Luagents.run_with_agent(agent, "What is 2 + 2?")
```

### Using Different LLM Providers

```elixir
# Use Ollama with a specific model
agent = Luagents.create_agent(
  name: "OllamaBot",
  llm: Luagents.create_llm(:ollama, model: "mistral")
)

# Use Anthropic Claude with a specific model
agent = Luagents.create_agent(
  name: "ClaudeBot",
  llm: Luagents.create_llm(:anthropic, model: "claude-3-opus-20240229")
)
```

### Adding Custom Tools

```elixir
# Define custom tools using deflua or anonymous functions
tools = %{
  power: Luagents.Tool.new(
    "power",
    "Calculate power (base^exponent)",
    [
      %{name: "base", type: :number, description: "Base number", required: true},
      %{name: "exp", type: :number, description: "Exponent", required: true}
    ],
    fn [base, exp] -> :math.pow(base, exp) end
  )
}

# Create agent with custom tools and configuration
agent = Luagents.create_agent(
  name: "MathBot",
  llm: Luagents.create_llm(:ollama, model: "mistral"),
  max_iterations: 15,
  tools: tools
)

{:ok, result} = Luagents.Agent.run(agent, "What is 10 to the power of 2?")
```

### Built-in Tools

Luagents provides several ready-to-use tools that can be easily added to your agents:

#### JSON Tools (`Luagents.Tools.Json`)
Parse, encode, and format JSON data within your Lua agent code. Enables seamless conversion between JSON strings and Lua tables for working with APIs and structured data.

- `parse(json_string)` - Parse JSON strings into Lua tables
- `encode(data)` - Encode Lua tables/values into JSON strings
- `pretty(data)` - Pretty-print JSON with formatting

#### HTTP Client (`Luagents.Tools.Http`)
Make HTTP requests to external APIs and services directly from your agent's Lua code. Supports all common HTTP methods with customizable headers and request bodies.

- `get(url, headers?)` - Make HTTP GET requests
- `post(url, body, headers?)` - Make HTTP POST requests
- `put(url, body, headers?)` - Make HTTP PUT requests
- `delete(url, headers?)` - Make HTTP DELETE requests

#### Logger (`Luagents.Tools.Logger`)
Log messages from your agent's reasoning process to Elixir's Logger at various levels. Useful for debugging, monitoring agent behavior, and capturing important events during task execution.

- `debug(message, metadata?)` - Log debug-level messages
- `info(message, metadata?)` - Log informational messages
- `warning(message, metadata?)` - Log warnings
- `error(message, metadata?)` - Log errors
- `log(level, message, metadata?)` - Log at a specific level with optional metadata

## Example Lua Thinking

The agent thinks in Lua code like this:

```lua
thought("I need to perform a calculation")

local a = 10
local b = 20
local sum = add(a, b)

observation("The sum is " .. sum)

local result = multiply(sum, 2)
thought("Multiplying by 2 gives " .. result)

final_answer("The result is " .. result)
```

## Contributing

Before opening a pull request, please open an issue first.

    git clone https://github.com/doomspork/luagents.git
    cd luagents 
    mix deps.get
    mix test

Once you've made your additions and `mix test` passes, go ahead and open a PR!

## License

Luagents is Copyright © 2025 doomspork. It is free software, and may be
redistributed under the terms specified in the [LICENSE](/LICENSE.md) file.