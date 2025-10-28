# Changelog

## [0.3.0](https://github.com/doomspork/luagents/compare/v0.2.0...v0.3.0) (2025-10-28)


### Features

* Add `Luagents.API` to improve perf of module registration ([16910c4](https://github.com/doomspork/luagents/commit/16910c48c354169152eb86a78e52bdb6dd1437c9))
* Include some out-of-the-box tools ([e715239](https://github.com/doomspork/luagents/commit/e71523938d7949a48055dfda86d86dff3040a001))
* Simplify how tools are registered and described ([b7be879](https://github.com/doomspork/luagents/commit/b7be879738a14b18d8a5610ea1c3969aec872e42))


### Bug Fixes

* Documents reference Anthropic default, make that true ([7e9a427](https://github.com/doomspork/luagents/commit/7e9a4276c2588ba438b82176de14d67bf45cf36f))
* Return a tuple, not string. Remove incorrect error message ([2545900](https://github.com/doomspork/luagents/commit/25459002f9ef2c788bee9dbaf252e095d3c7ded3))

## [0.2.0](https://github.com/doomspork/luagents/compare/v0.1.0...v0.2.0) (2025-08-05)


### Features

* Support deflua defined tools ([d76487f](https://github.com/doomspork/luagents/commit/d76487f5a918708cb49386ab33a841558c3e4950))

## v0.1.0 (2025-07-03)

### Features

- Initial release of `luagents`.
- Core agent framework for building agents that reason and act using Lua code.
- Support for multiple LLM providers, including Anthropic Claude and Ollama.
- Lua code execution and observation/answer reporting within agent workflows.
- Example usage and documentation.
