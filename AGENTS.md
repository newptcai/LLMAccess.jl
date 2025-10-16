# Agent Guide

This document consolidates the guidance previously spread across `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md`. Use it as the single reference for repository structure, development workflow, and LLM-specific behaviors.

## Project Overview
- `LLMAccess.jl` is a Julia package offering a unified interface to multiple LLM providers (OpenAI, Anthropic, Google, Mistral, Ollama, OpenRouter, Groq, DeepSeek, ZAI).
- The package ships CLI utilities in `script/` for common tasks such as Q&A, command generation, and echo testing.
- A modular architecture keeps provider-specific logic isolated while exposing a consistent API (`call_llm`) across backends.

### Key Features
- **Multi-provider dispatch:** Concrete `Provider` types share the `AbstractLLM` hierarchy; OpenAI-compatible services reuse `OpenAICompatibleLLM`.
- **Model alias resolution:** Shorthands (e.g., `4o-mini`, `flash`) map to full model IDs via `resolve_model_alias`.
- **Thinking mode:** Google Gemini, Anthropic Claude Sonnet/Opus, and Ollama support adjustable thinking budgets or toggles via `--think/-k`.
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
- Export API keys: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, `MISTRAL_API_KEY`, `OPENROUTER_API_KEY`, `GROQ_API_KEY`, `DEEPSEEK_API_KEY`, `ZAI_API_KEY`.
- Optional defaults: `DEFAULT_LLM`, `DEFAULT_TEMPERATURE`, `DEFAULT_<PROVIDER>_MODEL` (e.g., `DEFAULT_GOOGLE_MODEL="gemini-2.5-flash"`).
- Readers: `JINA_API_KEY` powers `jina_reader`; Pandoc must be installed for `pandoc_reader`.
- Keep secrets out of version control; prefer shell RC files or secret managers.

## Running the CLI
```bash
# Ask a question with Google Gemini
julia --project script/ask.jl --llm google "Hello"

# Generate commands with OpenAI GPT-4o Mini
julia --project script/cmd.jl --llm openai --model 4o-mini "list files changed today"

# Bypass the LLM and test command/clipboard flow
julia --project script/cmd.jl --cmd 'echo hi'
```

Common flags:
- `--llm/-l` provider selection
- `--model/-m` model override (aliases supported)
- `--attachment/-a` attach files for multimodal requests
- `--temperature/-t` sampling control
- `--think/-k` provider-specific thinking budget or toggle
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
- Groq omits system instructions when attachments are provided to satisfy API requirements.
- Ollama treats any non-zero `--think` value as enabling thinking mode.
- `script/cmd.jl` always copies trimmed command output; confirm clipboard access on your platform.
