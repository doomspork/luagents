# Contributing to Luagents

Thank you for your interest in contributing to Luagents! We welcome contributions from the community.

## Reporting Issues

If you encounter a bug or have a feature request:

1. Check existing [GitHub issues](https://github.com/doomspork/luagents/issues) to avoid duplicates
2. Create a new issue with a clear title and description
3. Include reproduction steps for bugs
4. Provide context for feature requests (use case, expected behavior)

## Contributing Code

### Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/luagents.git`
3. Install dependencies: `mix deps.get`
4. Run tests to ensure everything works: `mix test`

### Development Workflow

1. Create a feature branch: `git checkout -b feature/your-feature-name`
2. Make your changes
3. Write or update tests for your changes
4. Run the full test suite: `mix test`
5. Run code quality checks: `mix credo`
6. Run type checking: `mix dialyzer`
7. Commit your changes with clear, descriptive messages using conventional commit formatting
8. Push to your fork and create a pull request

### Code Standards

- **Keep changes focused**: Each PR should address a single concern
- **Write tests**: All new functionality must include tests
- **Minimize comments**: Write self-documenting code; use comments only when necessary to explain "why" not "what"
- **Follow Elixir conventions**: Use consistent formatting and naming
- **Type specifications**: Add `@spec` annotations for public functions
- **Documentation**: Update relevant documentation and docstrings

### Testing Requirements

All contributions must:
- Include tests that cover new functionality or bug fixes
- Pass the existing test suite: `mix test`
- Maintain or improve code coverage
- Pass Dialyzer type checking: `mix dialyzer`
- Pass Credo code quality checks: `mix credo`

### AI-Assisted Development

We embrace AI tools for development, but with clear guidelines:

- **AI usage is encouraged** for code generation, refactoring, and problem-solving
- **Testing is mandatory**: All AI-generated code must be thoroughly tested
- **Human review required**: Understand and verify all AI-generated code before submitting
- **Keep changes narrow**: Focus on specific, well-defined improvements
- **Minimize comments**: AI often over-comments; remove unnecessary explanations
- **CI checks must pass**: All automated checks (tests, Dialyzer, Credo) must pass before merge

Remember: AI is a tool to augment your development, not replace thoughtful engineering.

## Pull Request Process

1. Ensure all tests pass and CI checks are green
2. Update documentation if you've changed APIs or behavior
3. Add your changes to the changelog (if applicable)
4. Request review from maintainers
5. Address any feedback or requested changes
6. Once approved, a maintainer will merge your PR

## Questions?

If you have questions about contributing, feel free to open an issue for discussion.

## License

By contributing to Luagents, you agree that your contributions will be licensed under the same license as the project.