# LLMAccess

LLMAccess is a Julia package designed to simplify interactions with multiple Large Language Model (LLM) APIs. It provides a unified interface to integrate models from providers such as OpenAI, Anthropic, Google, Ollama, Mistral, OpenRouter, Groq, and DeepSeek into your Julia scripts seamlessly, plus shared CLI helpers for argument parsing and robust error handling.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Importing the Module](#importing-the-module)
  - [Calling an LLM](#calling-an-llm)
    - [Example: OpenAI](#example-openai)
    - [Example: Google](#example-google)
  - [Model Aliases](#model-aliases)
  - [Using with Command-Line](#using-with-command-line)
- [Supported LLM Providers](#supported-llm-providers)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Multi-Provider Support**: Seamlessly interact with multiple LLM providers through a single interface.
- **File Attachments**: Easily attach files to API requests.
- **Command-Line Integration**: Parse command-line arguments for flexible script execution.
- **Model Aliases**: Use convenient shorthand names for popular models (e.g. `4o` for GPT-4o, `haiku` for Claude 3 Haiku)
- **Extensibility**: Add support for new LLM providers with minimal effort.
- **Error Handling**: Manage API request failures gracefully with robust error handling.

## Installation

To install LLMAccess, use Julia's package manager. In your Julia REPL, run:

```julia
using Pkg
Pkg.add("git@gitlab.com:newptcai/llmaccess.jl.git")
```

If working from a clone of this repo, instantiate the environment:

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

## Configuration

Before using LLMAccess, set the necessary API keys for the LLM providers you want to use. Set these as environment variables:

- `OPENAI_API_KEY` for OpenAI
- `OPENROUTER_API_KEY` for OpenRouter
- `GROQ_API_KEY` for Groq
- `ANTHROPIC_API_KEY` for Anthropic
- `GOOGLE_API_KEY` for Google
- `MISTRAL_API_KEY` for Mistral
- `DEEPSEEK_API_KEY` for DeepSeek

### Setting Environment Variables

**On Unix/Linux/macOS:**

Add the following lines to your shell configuration file (e.g., `.bashrc`, `.zshrc`):

```bash
export OPENAI_API_KEY="your_openai_api_key"
export OPENROUTER_API_KEY="your_openrouter_api_key"
export GROQ_API_KEY="your_groq_api_key"
export ANTHROPIC_API_KEY="your_anthropic_api_key"
export GOOGLE_API_KEY="your_google_api_key"
export MISTRAL_API_KEY="your_mistral_api_key"
```

To set the default LLM provider and models, add the following lines:

```bash
export DEFAULT_LLM="ollama"
export DEFAULT_OPENAI_MODEL="gpt-4o-mini"
export DEFAULT_OPENROUTER_MODEL="amazon/nova-micro-v1"
export DEFAULT_ANTHROPIC_MODEL="claude-3-5-haiku-latest"
export DEFAULT_GOOGLE_MODEL="gemini-2.0-flash"
export DEFAULT_OLLAMA_MODEL="gemma3:4b"
export DEFAULT_MISTRAL_MODEL="mistral-small-latest"
export DEFAULT_GROQ_MODEL="llama-3.3-70b-versatile"
export DEFAULT_DEEPSEEK_MODEL="deepseek-chat"
```

After adding the variables, reload your shell configuration:

```bash
source ~/.bashrc
# or
source ~/.zshrc
```

**On Windows:**

Set environment variables through the System Properties:

1. Open **System Properties**.
2. Navigate to **Advanced** > **Environment Variables**.
3. Under **User variables** or **System variables**, click **New**.
4. Enter the variable name (e.g., `OPENAI_API_KEY`) and your API key as the value.
5. Click **OK** to save.

## Usage

### Importing the Module

Start by importing the LLMAccess module in your Julia script:

```julia
using LLMAccess
```

### Calling an LLM

The `call_llm` function interacts with the specified LLM provider.
You can create an instance of the desired LLM type and invoke the function with the
necessary parameters.

#### Example: OpenAI

```julia
using LLMAccess

# Create an OpenAI LLM instance
openai_llm = OpenAILLM()

# Define input text and system instructions
input_text = "Hello, how are you?"
system_instruction = "You are a helpful assistant."

# Call the OpenAI LLM
response = call_llm(openai_llm, system_instruction, input_text)

println("OpenAI Response: ", response)
```

#### Example: Google

```julia
using LLMAccess

# Create a Google LLM instance
google_llm = GoogleLLM()

# Define input text and system instructions
input_text = "Translate this text to French."
system_instruction = "You are a translation assistant."

# Call the Google LLM
response = call_llm(google_llm, system_instruction, input_text)

println("Google Response: ", response)
```

### Model Aliases

LLMAccess supports shorthand names for common models. Here are some key aliases:

| Alias | Full Model Name |
|---|---|
| `small` | `mistral-small-latest` |
| `medium` | `mistral-medium-latest` |
| `large` | `mistral-large-latest` |
| `gemini` | `gemini-2.5-pro` |
| `flash` | `gemini-2.5-flash` |
| `sonnet` | `claude-sonnet-4-20250514` |
| `opus` | `claude-opus-4-1-20250805` |
| `haiku` | `claude-3-5-haiku-latest` |
| `magistral` | `magistral-medium-latest` |
| `r1` | `deepseek-reasoner` |
| `v3` | `deepseek-chat` |
| `4o` | `gpt-4o` |
| `4o-mini` | `gpt-4o-mini` |
| `3.5` | `gpt-3.5-turbo` |
| `5` | `gpt-5` |
| `5-mini` | `gpt-5-mini` |

Use these aliases anywhere you would specify a model name. For example:

```julia
# Using alias instead of full model name
response = call_llm("openai", "You are helpful", "Hello", model="4o")
```

To list all available aliases from the CLI, run:

```bash
julia --project script/ask.jl --alias
# or
julia --project script/ask.jl -A
```

### Thinking Budget (`--think`, `-k`)

- Default now varies by model:
  - Gemini: `-1` (dynamic)
  - Claude Sonnet: `0` (disabled)
  - DeepSeek Reasoner: `0` (not used by API)
  - Mistral/Magistral: `0` (not used by API)
- Pass an explicit value to override (e.g., `-k 1000`).
- Providers that don’t support “thinking” ignore this option.

### CLI Scripts

LLMAccess ships with runnable scripts and shared CLI helpers:`parse_commandline` for consistent flags and `run_cli` for robust error handling (usage errors, Ctrl+C, debug traces).

- `script/ask.jl` — General-purpose Q&A.
- `script/cmd.jl` — Generates bash commands (prints and copies to clipboard).
- `script/echo.jl` — Echo utility for validating responses.

Examples:

```bash
# Default provider (google)
julia --project script/ask.jl "What is 2+2?"

# OpenAI with model alias
julia --project script/ask.jl --llm openai --model 4o "Summarize this repo"

# Generate shell commands
julia --project script/cmd.jl --llm openai "list files changed today"

# Vision with attachments
julia --project script/ask.jl --llm openai --model 4o --attachment ~/Downloads/example.webp "What's in this picture?"
```

Common arguments:

- `--llm, -l`: LLM provider (`openai`, `anthropic`, `google`, `ollama`, `mistral`, `openrouter`, `groq`, `deepseek`). Defaults to `DEFAULT_LLM` or `google`.
- `--model, -m`: Model name; supports aliases below. Defaults to provider’s default.
- `--file, -f`: Path to input file to process (optional; reserved for helpers that consume files).
- `--attachment, -a`: Path to a file to attach (e.g., image for vision APIs).
- `--temperature, -t`: Sampling temperature (default: 1.0).
- `--debug, -d`: Enable debug logging and richer error output.
- `--copy, -c`: Copy response to clipboard.
- `--think, -k`: Enable “thinking” for providers that support it (e.g., Gemini, Claude, Ollama). For Gemini/Claude, this is a token budget (e.g., `-k 1000`). For Ollama, any non-zero enables thinking.
- `--alias, -A`: Print all model aliases and exit.
- `--dry-run, -D`: Print the JSON payload that would be sent and exit (no network call).
- `input_text` (positional): Prompt text; if omitted and required, stdin is read.

### Dry Run

Use `--dry-run` to inspect the exact JSON payload without sending a request. This is useful for testing.

Examples:

```bash
# Ollama dry run
julia --project script/ask.jl --llm ollama -D "Hello"

# Google with attachment (no request made)
julia --project script/ask.jl --llm google --attachment image.png --dry-run "describe"
```

## Supported LLM Providers

LLMAccess currently supports the following LLM providers:

- **OpenAI**: Access to models like GPT-4, GPT-3.5, etc.
- **OpenRouter**: Compatible with OpenAI's API endpoints.
- **Groq**: Integrates with Groq's LLM services.
- **DeepSeek**: OpenAI-compatible API access to DeepSeek's models.
- **Anthropic**: Utilizes Anthropic's Claude models.
- **Google**: Connects to Google's generative language models.
- **Ollama**: Interfaces with Ollama's local LLM deployments.
- **Mistral**: Access to Mistral's LLM offerings.

You can call providers using typed instances (e.g., `call_llm(GoogleLLM(), ...)`) or by name via `call_llm(llm_name, system_instruction, input_text; model, temperature, copy, think)`.

## Contributing

Contributions are welcome! If you'd like to contribute to LLMAccess, please fork the repository and create a pull request.

## License

This project is licensed under the [MIT License](LICENSE).
