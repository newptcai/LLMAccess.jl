# Repository Guidelines

## Project Structure & Module Organization
- `src/LLMAccess.jl`: Main module with providers, request helpers, and CLI parsing.
- `test/runtests.jl`: Unit/integration tests using Julia `Test` stdlib.
- `script/`: Runnable examples and utilities (`ask.jl`, `cmd.jl`, `echo.jl`).
- `Project.toml` / `Manifest.toml`: Package metadata and dependency lock.

## Build, Test, and Development Commands
- Install deps: `julia --project -e 'using Pkg; Pkg.instantiate()'`
- Run tests: `julia --project -e 'using Pkg; Pkg.test()'`
  - Integration tests call external LLM APIs. Ensure provider API keys are set (see README) and network is available.
- Run scripts:
  - `julia --project script/ask.jl --llm google "Hello"`
  - `julia --project script/cmd.jl --llm openai "list files changed today"`

## Coding Style & Naming Conventions
- Julia style, 4-space indentation, no trailing whitespace.
- Functions and variables: `snake_case` (e.g., `call_llm`, `get_default_model`).
- Module is `LLMAccess` (single top-level module in `src/`).
- Add docstrings using triple quotes above public APIs.
- Prefer small, composable functions; keep provider-specific logic isolated to typed methods.

## Testing Guidelines
- Framework: `Test` stdlib (`using Test`). Add new tests under `test/runtests.jl` or split into files and include them from there.
- Keep fast, unit-level tests near helpers; mark or isolate API-calling tests to keep local runs reliable.
- Run with keys set (e.g., `OPENAI_API_KEY`, `GOOGLE_API_KEY`, etc.). Avoid hard-coding secrets.

## Commit & Pull Request Guidelines
- Use Conventional Commits (emoji optional) and scopes where helpful:
  - Examples: `feat(LLMAccess): add DeepSeek alias`, `fix: handle 404 from Mistral`, `docs(README): update CLI flags`, `chore: bump version`.
- PRs should include:
  - Clear description, rationale, and before/after behavior.
  - Linked issues (e.g., `Fixes #123`).
  - Tests for new behavior or bug fixes and updates to README when user-facing changes occur.

## Security & Configuration Tips
- Configure providers via environment variables (e.g., `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, etc.).
- Do not commit secrets. Use your shell rc or a secure secret manager.
- You can set default models via env (e.g., `DEFAULT_OPENAI_MODEL`); see README for the full list and examples.

