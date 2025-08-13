# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LLMAccess is a Julia package that provides a unified interface for multiple Large Language Model providers including OpenAI, Anthropic, Google, Ollama, Mistral, OpenRouter, Groq, and DeepSeek. The package allows seamless switching between providers while maintaining consistent API usage.

## Development Commands

### Testing
```bash
julia --project=. -e "using Pkg; Pkg.test()"
```

### Running Scripts
The `script/` directory contains example applications:
- `script/ask.jl` - General-purpose Q&A interface
- `script/cmd.jl` - Command-line generation tool (outputs bash commands)
- `script/echo.jl` - Testing utility for LLM response validation

Run scripts with:
```bash
julia --project=. script/ask.jl --llm google "What is 2+2?"
julia --project=. script/cmd.jl "List files modified in last 7 days"
```

### Package Management
```bash
# Install dependencies
julia --project=. -e "using Pkg; Pkg.instantiate()"

# Update dependencies
julia --project=. -e "using Pkg; Pkg.update()"
```

## Architecture Overview

### Core Components

1. **Abstract Type Hierarchy**: `AbstractLLM` → `OpenAICompatibleLLM` for providers using OpenAI-style APIs
2. **Provider Types**: Concrete types for each LLM provider (OpenAILLM, AnthropicLLM, GoogleLLM, etc.)
3. **Unified Interface**: Single `call_llm()` function with multiple dispatch based on provider type
4. **Model Aliasing**: Convenient shorthand names (e.g., `4o` → `gpt-4o`, `sonnet` → `claude-sonnet-4-20250514`)

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
export DEFAULT_GOOGLE_MODEL="gemini-2.0-flash"
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