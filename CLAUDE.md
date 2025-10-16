# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LLMAccess is a Julia package that provides a unified interface for multiple Large Language Model providers including OpenAI, Anthropic, Google, Ollama, Mistral, OpenRouter, Groq, and DeepSeek. The package allows seamless switching between providers while maintaining consistent API usage.

## Project Structure & Module Organization

- `src/LLMAccess.jl`: Main module with providers, request helpers, and CLI parsing
- `test/runtests.jl`: Unit/integration tests using Julia `Test` stdlib
- `script/`: Runnable examples and utilities (`ask.jl`, `cmd.jl`, `echo.jl`)
- `Project.toml` / `Manifest.toml`: Package metadata and dependency lock

## Build, Test, and Development Commands

### Install Dependencies
```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

### Testing
```bash
julia --project -e 'using Pkg; Pkg.test()'
```

**Important**: Integration tests call external LLM APIs. Ensure provider API keys are set and network is available.

### Running Scripts
The `script/` directory contains example applications:
- `script/ask.jl` - General-purpose Q&A interface
- `script/cmd.jl` - Command-line generation tool (outputs bash commands)
- `script/echo.jl` - Testing utility for LLM response validation

Run scripts with:
```bash
julia --project script/ask.jl --llm google "Hello"
julia --project script/cmd.jl --llm openai "list files changed today"
```

## Architecture Overview

### Core Components

1. **Abstract Type Hierarchy**: `AbstractLLM` → `OpenAICompatibleLLM` for providers using OpenAI-style APIs
2. **Provider Types**: Concrete types for each LLM provider (OpenAILLM, AnthropicLLM, GoogleLLM, etc.)
3. **Unified Interface**: Single `call_llm()` function with multiple dispatch based on provider type
4. **Model Aliasing**: Convenient shorthand names (e.g., `4o` → `gpt-4o`, `sonnet` → `claude-sonnet-4-5-20250929`)

### Key Files

- `src/LLMAccess.jl` - Main module containing all provider implementations
- `Project.toml` - Package metadata and dependencies
- `test/runtests.jl` - Test suite including integration tests

### Provider-Specific Implementations

Each LLM provider has:
- Unique authentication (API keys via environment variables)
- Custom request formatting (headers, payload structure)
- Response parsing logic
- File attachment handling (different base64 encoding formats)

### Special Features

- **Thinking Mode**: Supported by Anthropic (budget-based) and Google/Ollama models
- **File Attachments**: Base64 encoding with MIME type detection for images/documents
- **Temperature Control**: Sampling parameter configuration across all providers
- **Error Handling**: Comprehensive HTTP error parsing and reporting

## Environment Configuration

Set API keys as environment variables:
```bash
export OPENAI_API_KEY="your_key"
export ANTHROPIC_API_KEY="your_key" 
export GOOGLE_API_KEY="your_key"
# ... other providers
```

Configure default models:
```bash
export DEFAULT_LLM="google"
export DEFAULT_GOOGLE_MODEL="gemini-2.5-flash"
# ... other defaults
```

## Command-Line Interface

The package provides rich command-line argument parsing with:
- Provider selection (`--llm`, `-l`)
- Model specification (`--model`, `-m`) 
- File attachments (`--attachment`, `-a`)
- Temperature control (`--temperature`, `-t`)
- Thinking mode (`--think`, `-k`)
- Debug logging (`--debug`, `-d`)
- Clipboard integration (`--copy`, `-c`)

## Development Patterns

- All LLM implementations follow the same signature: `call_llm(llm, system_instruction, input_text, model, temperature, attach_file; kwargs...)`
- File encoding is abstracted through multiple dispatch on LLM types
- Error handling is centralized in `post_request()` and `handle_json_response()`
- Model resolution happens through `resolve_model_alias()` before API calls
- Debug logging is available throughout the codebase using `@debug` macros

## Coding Style & Naming Conventions

- Julia style, 4-space indentation, no trailing whitespace
- Functions and variables: `snake_case` (e.g., `call_llm`, `get_default_model`)
- Module is `LLMAccess` (single top-level module in `src/`)
- Add docstrings using triple quotes above public APIs
- Prefer small, composable functions; keep provider-specific logic isolated to typed methods

## Testing Guidelines

- Framework: `Test` stdlib (`using Test`). Add new tests under `test/runtests.jl` or split into files and include them from there
- Keep fast, unit-level tests near helpers; mark or isolate API-calling tests to keep local runs reliable
- Run with keys set (e.g., `OPENAI_API_KEY`, `GOOGLE_API_KEY`, etc.). Avoid hard-coding secrets

## Commit & Pull Request Guidelines

- Use Conventional Commits (emoji optional) and scopes where helpful:
  - Examples: `feat(LLMAccess): add DeepSeek alias`, `fix: handle 404 from Mistral`, `docs(README): update CLI flags`, `chore: bump version`
- PRs should include:
  - Clear description, rationale, and before/after behavior
  - Linked issues (e.g., `Fixes #123`)
  - Tests for new behavior or bug fixes and updates to README when user-facing changes occur

## Security & Configuration Tips

- Configure providers via environment variables (e.g., `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, etc.)
- Do not commit secrets. Use your shell rc or a secure secret manager
- You can set default models via env (e.g., `DEFAULT_OPENAI_MODEL`); see README for the full list and examples
