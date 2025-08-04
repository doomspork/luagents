# Luagents

[![Continuous Integration](https://github.com/doomspork/luagents/actions/workflows/ci.yml/badge.svg)](https://github.com/doomspork/luagents/actions/workflows/ci.yaml)
[![Module Version](https://img.shields.io/hexpm/v/luagents.svg)](https://hex.pm/packages/luagents)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/luagents/)
[![Total Download](https://img.shields.io/hexpm/dt/luagents.svg)](https://hex.pm/packages/luagents)
[![License](https://img.shields.io/hexpm/l/luagents.svg)](https://github.com/doomspork/luagents/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/doomspork/luagents.svg)](https://github.com/doomspork/luagents/commits/master)

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
2. Pull a model (e.g., `ollama pull llama3.2`)
3. Create an agent with Ollama provider:

```elixir
agent = Luagents.Agent.new(
  llm: Luagents.LLM.new(provider: :ollama, model: "llama3.2")
)
```

## Usage

### Basic Usage

```elixir
# Create an agent with Anthropic Claude (default)
agent = Luagents.Agent.new()

# Or specify the provider explicitly  
agent = Luagents.Agent.new(
  llm: Luagents.LLM.new(provider: :anthropic)
)

# Use Ollama instead
agent = Luagents.Agent.new(
  llm: Luagents.LLM.new(provider: :ollama, model: "llama3.2")
)

# Run a task
{:ok, result} = Luagents.Agent.run(agent, "What is 2 + 2?")
```

### Advanced Usage

```elixir
anthropic_agent = Luagents.Agent.new(
  name: "Claude Agent",
  llm: Luagents.LLM.new(provider: :anthropic, model: "claude-3-sonnet-20240229")
)

ollama_agent = Luagents.Agent.new(
  name: "Ollama Agent", 
  llm: Luagents.LLM.new(provider: :ollama, model: "llama3.2", host: "http://localhost:11434")
)

agent = Luagents.Agent.new(
  name: "MyAgent",
  max_iterations: 10,
  llm: Luagents.LLM.new(
    model: "claude-3-opus-20240229",
    temperature: 0.5
  )
)

{:ok, result} = Luagents.run_with_agent(agent, "Hello!")
```

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