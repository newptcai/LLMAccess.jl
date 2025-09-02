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
  - `julia --project script/ask.jl -A` (or `--alias`) to print all model aliases and exit.
  - `julia --project script/ask.jl -D --llm google --attachment img.png "describe"` to print the JSON payload without sending.

## CLI Flags Quick Reference
- `--llm, -l`: Provider (`openai`, `anthropic`, `google`, `ollama`, `mistral`, `openrouter`, `groq`, `deepseek`).
- `--model, -m`: Model name (supports aliases; defaults per provider env or built-in).
- `--attachment, -a`: Path to file to attach (e.g., image for vision models).
- `--file, -f`: Input file path (optional; some scripts may use it).
- `--temperature, -t`: Sampling temperature (Float64; default 1.0 unless overridden by env).
- `--debug, -d`: Enable debug logging and verbose error output.
- `--copy, -c`: Copy response to clipboard (scripts that support it).
- `--think, -k`: Thinking budget for supported providers (e.g., Gemini, Claude).
- `--alias, -A`: Print all model aliases and exit.
- `--dry-run, -D`: Print the request JSON and exit (no network call).

## Coding Style & Naming Conventions
- Julia style, 4-space indentation, no trailing whitespace.
- Functions and variables: `snake_case` (e.g., `call_llm`, `get_default_model`).
- Module is `LLMAccess` (single top-level module in `src/`).
- Add docstrings using triple quotes above public APIs.
- Prefer small, composable functions; keep provider-specific logic isolated to typed methods.

### Public API and Utilities (from `src/`)
- `call_llm(...)`: Multi-method dispatch by provider type and name; supports attachments and dry-run.
- `list_llm_models(llm::Provider)`: Lists models for Google, Anthropic, OpenRouter, Groq, OpenAI, Mistral, DeepSeek, Ollama.
- `parse_commandline(...)` and `run_cli(...)`: Centralized CLI parsing and robust error handling.
- Readers: `jina_reader(url)` (requires `JINA_API_KEY`) and `pandoc_reader(url)` (uses Pandoc) for fetching/markdown conversion.

## Testing Guidelines
- Framework: `Test` stdlib (`using Test`). Add new tests under `test/runtests.jl` or split into files and include them from there.
- Keep fast, unit-level tests near helpers; mark or isolate API-calling tests to keep local runs reliable.
- Run with keys set (e.g., `OPENAI_API_KEY`, `GOOGLE_API_KEY`, etc.). Avoid hard-coding secrets.
  - Optional: integration tests gated by `LLMACCESS_RUN_INTEGRATION=1` (see `test/runtests.jl`).

## Commit & Pull Request Guidelines
- Use Conventional Commits (emoji optional) and scopes where helpful:
  - Examples: `feat(LLMAccess): add DeepSeek alias`, `fix: handle 404 from Mistral`, `docs(README): update CLI flags`, `chore: bump version`.
- PRs should include:
  - Clear description, rationale, and before/after behavior.
  - Linked issues (e.g., `Fixes #123`).
  - Tests for new behavior or bug fixes and updates to README when user-facing changes occur.

## Security & Configuration Tips
- Configure providers via environment variables:
  - Core: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `MISTRAL_API_KEY`.
  - OpenAI-compatible: `OPENROUTER_API_KEY`, `GROQ_API_KEY`, `DEEPSEEK_API_KEY`.
  - Readers: `JINA_API_KEY` for `jina_reader`; Pandoc must be installed for `pandoc_reader`.
- Do not commit secrets. Use your shell rc or a secure secret manager.
- Defaults via env:
  - `DEFAULT_LLM` (default provider; current default is `google`).
  - `DEFAULT_TEMPERATURE` (Float; fallback 1.0).
  - `DEFAULT_<PROVIDER>_MODEL` (e.g., `DEFAULT_OPENAI_MODEL`, `DEFAULT_GOOGLE_MODEL`, etc.).

## Behavior Notes (as implemented in `src/`)
- Model aliases: Resolved via `MODEL_ALIASES` (e.g., `flash` => `gemini-2.5-flash`, `4o-mini` => `gpt-4o-mini`). Use `--alias/-A` to print all.
- Attachments: Images supported across providers with provider-specific payloads (OpenAI-compatible `image_url`, Google `inline_data`, Anthropic base64 image, Mistral multimodal, Ollama `images`).
- Thinking budget (`--think/-k`):
  - Google: Sets `generationConfig.thinkingConfig.thinkingBudget` when non-zero; default is `-1` for Gemini models.
  - Anthropic: Enabled for Sonnet ≥ 3.7 and Opus ≥ 4; sets `thinking` and adjusts `max_tokens`/temperature.
  - Others default to 0 (disabled).
- Dry run: `-D/--dry-run` returns the exact JSON payload without sending the request.
