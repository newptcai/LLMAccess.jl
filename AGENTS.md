# Agent Guide

This document consolidates the guidance previously spread across `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md`. Use it as the single reference for repository structure, development workflow, and LLM-specific behaviors.

## Project Overview
- `LLMAccess.jl` is a Julia package offering a unified interface to multiple LLM providers (OpenAI, Anthropic, Google, Mistral, OpenRouter, DeepSeek, Ollama, Ollama Cloud).
- The package ships CLI utilities in `script/` for common tasks such as Q&A, command generation, and echo testing.
- A modular architecture keeps provider-specific logic isolated while exposing a consistent API (`call_llm`) across backends.

### Key Features
- **Multi-provider dispatch:** Concrete `Provider` types share the `AbstractLLM` hierarchy; OpenAI-compatible services reuse `OpenAICompatibleLLM`.
- **Model alias resolution:** Shorthands (e.g., `4o-mini`, `flash`) map to full model IDs via `resolve_model_alias`.
- **Thinking mode:** Google Gemini, Anthropic Claude Sonnet/Opus, OpenAI GPT-5, and Ollama (local + cloud) support adjustable thinking budgets/toggles via `--think/-k`.
- **Attachment handling:** Provider-specific encoders support inline/base64 image uploads with correct MIME metadata.
- **Robust error reporting:** HTTP failures are parsed into actionable messages; `--debug/-d` emits verbose diagnostics.

### Core Technologies
- **Language:** Julia
- **Key dependencies:** `ArgParse`, `HTTP`, `JSON`

## Repository Layout
- `src/LLMAccess.jl`: Main module with provider implementations, request helpers, and CLI parsing.
- `script/`: Example entry points (`ask.jl`, `cmd.jl`, `echo.jl`) that invoke `run_cli`.
- `test/runtests.jl`: Unit and integration tests using the `Test` stdlib.
- `Project.toml` / `Manifest.toml`: Environment metadata and dependency lockfiles.

## Environment Setup
```bash
# Clone and develop locally
julia --project -e 'using Pkg; Pkg.instantiate()'
```

Optional workflows:
- Add directly from the Julia REPL package manager: `Pkg.add(url="https://gitlab.com/newptcai/llmaccess.jl.git")`
- Develop a local checkout: `pkg> dev /path/to/llmaccess.jl`

### Provider Configuration
- Export API keys: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `MISTRAL_API_KEY`, `OPENROUTER_API_KEY`, `DEEPSEEK_API_KEY`, `OLLAMA_API_KEY` (cloud only). The local Ollama daemon does not require a key.
- Optional defaults: `DEFAULT_LLM`, `DEFAULT_TEMPERATURE`, `DEFAULT_<PROVIDER>_MODEL` (e.g., `DEFAULT_GOOGLE_MODEL="gemini-2.5-flash"`).
- Readers: `JINA_API_KEY` powers `jina_reader`; Pandoc must be installed for `pandoc_reader`.
- Keep secrets out of version control; prefer shell RC files or secret managers.

## Running the CLI
```bash
# Ask a question with Google Gemini
julia --project script/ask.jl --llm google "Hello"

# Generate commands with OpenAI GPT-5.1
julia --project script/cmd.jl --llm openai --model 5.1 "list files changed today"

# Bypass the LLM and test command/clipboard flow
julia --project script/cmd.jl --cmd 'echo hi'
```

Common flags:
- `--llm/-l` provider selection (`openai`, `anthropic`, `google`, `ollama`, `ollama_cloud`, `mistral`, `openrouter`, `deepseek`)
- `--model/-m` model override (aliases supported)
- `--attachment/-a` attach files for multimodal requests
- `--temperature/-t` sampling control
- `--think/-k` provider-specific thinking budget or toggle (0-4 for GPT-5 models; any non-zero value enables Ollama/Ollama Cloud reasoning)
- `--debug/-d` verbose logging
- `--copy/-c` copy responses to the clipboard
- `--alias/-A` list all model aliases and exit
- `--dry-run/-D` print the outbound JSON payload without sending the request

## Architecture Highlights
- Centralized `call_llm` multimethod dispatch chooses provider-specific request builders.
- Provider types encapsulate authentication headers, payload schemas, and response parsing.
- `resolve_model_alias`, `default_think_for_model`, and `is_anthropic_thinking_model` standardize model behavior.
- Error handling flows through helpers such as `post_request` and `handle_json_response`.
- CLI parsing delegates to `parse_commandline`, `create_default_settings`, and `run_cli` for consistent UX across scripts.

## Development Guidelines
- Follow Julia style: 4-space indentation, `snake_case` identifiers, no trailing whitespace.
- Document public APIs with triple-quoted docstrings.
- Favor small, composable functions; keep provider-specific logic within typed methods.
- Leverage `@debug` logging for introspection when `--debug` is enabled.
- When adding providers or features, emulate existing provider structures and reuse shared helpers.

### Adding New OpenAI-Compatible Providers
To add a new provider that is compatible with the OpenAI API, follow these steps:

1.  **Define Structs and Default Models (`src/core/types_constants.jl`):**
    *   Create a new concrete `struct` that subtypes `OpenAICompatibleLLM` (e.g., `struct MyNewLLM <: OpenAICompatibleLLM end`).
    *   Add the new struct to the `export` list within the `Core` module in `src/LLMAccess.jl`.
    *   Update the `DEFAULT_MODELS` dictionary to include a default model for your new provider (e.g., `\"mynewllm\" => \"default-model-name\"`).
    *   Optionally, add aliases for your provider to the `PROVIDER_ALIASES` dictionary (e.g., `\"mn\" => \"mynewllm\"`).

2.  **Register Provider (`src/dispatch.jl`):**
    *   Add an entry to the `llm_types` dictionary within the `get_llm_type` function, mapping the provider's canonical string name to an instance of its struct (e.g., `\"mynewllm\" => MyNewLLM()`).

3.  **Implement `call_llm` Method (`src/providers/openai_compat.jl`):**
    *   Create a new `call_llm` method that dispatches on your new provider's struct type (e.g., `function call_llm(llm::MyNewLLM, ...) end`).
    *   Inside this method, define how to retrieve the API key (e.g., `ENV["MYNEWLLM_API_KEY"]`) and the base URL for the API endpoint (e.g., `\"https://api.mynewllm.com/v1/chat/completions\"`).
    *   Call `make_api_request` with the appropriate parameters.

4.  **Add Integration Tests (`test/runtests.jl`):**
    *   In the `if get(ENV, "LLMACCESS_RUN_INTEGRATION", "0") == "1"` block, add `test_llm(get_llm_type(\"mynewllm\"))` to ensure basic functionality.

5.  **Update Documentation:**
    *   Modify `README.md` to include your new provider in the "Configuration" section (API key, default model environment variables), "Provider Aliases," and "Supported LLM Providers" sections.
    *   Update `docs/src/cli.md` to reflect new provider flags and aliases.

6.  **Rebuild Documentation (if necessary):**
    *   If you've added new docstrings, rebuild the documentation using the standard Julia `Documenter.jl` workflow.


## Testing
- Unit tests live in `test/runtests.jl`; split additional files and include them as needed.
- Keep fast tests near helper functions; gate API-calling integration tests behind environment checks (e.g., `LLMACCESS_RUN_INTEGRATION=1`).
- Run from the shell: `julia --project -e 'using Pkg; Pkg.test()'`.
- Ensure required API keys are available; avoid hard-coding credentials.

## Commit & PR Practices
- Use Conventional Commit style with optional emoji scopes (e.g., `✨ (script/cmd.jl): Add dry-run flag hint`).
- PRs should explain purpose, include before/after behavior, and reference issues when relevant.
- Add or update tests alongside behavioral changes; refresh documentation for user-facing updates.

## Additional Tips
- Model alias listings help verify available shorthands: `julia --project script/ask.jl -A`.
- Any non-zero `--think` value enables reasoning mode for Ollama (local + cloud).
- GPT-5.1 uses reasoning effort levels 0-4: 0=none (default), 1=minimal→low, 2=low, 3=medium, 4=high.
- `script/cmd.jl` always copies trimmed command output; confirm clipboard access on your platform.
- `script/cmd.jl` recognizes `{{FILE}}`/`{{F}}` placeholders (plus the `|cmd` variant) to inject the `-f/--file` path or run a short `bash -lc` snippet with the original path available via STDIN and `$FILE_PLACEHOLDER`.
- When a CLI should hide unused shared flags or replace them with custom options, pass `omit_args = [...]` into `parse_commandline` via `run_cli_with_args` (see `script/cmd.jl` omitting `--copy` in favor of `--no-copy` and skipping `--no-normalize`).

## TODO
- CLI scripts: wrap the repeated `args_ref` + `run_cli` boilerplate used in `script/ask.jl`, `script/cmd.jl`, and `script/echo.jl` in a common helper so each script only supplies its specific prompt/behavior.
