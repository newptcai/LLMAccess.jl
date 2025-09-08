# LLMAccess

LLMAccess is a Julia package designed to simplify interactions with multiple Large Language Model (LLM) APIs. It provides a unified interface to integrate models from providers such as OpenAI, Anthropic, Google, Ollama, Mistral, OpenRouter, Groq, and DeepSeek into your Julia scripts seamlessly, plus shared CLI helpers for argument parsing and robust error handling.

## Table of Contents

- [Features](#features)
- [Documentation](#documentation)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Importing the Module](#importing-the-module)
  - [Calling an LLM](#calling-an-llm)
    - [Example: OpenAI](#example-openai)
    - [Example: Google](#example-google)
    - [Example: Z.ai](#example-zai)
  - [Model Aliases](#model-aliases)
  - [Thinking Budget (`--think`, `-k`)](#thinking-budget--think--k)
  - [CLI Scripts](#cli-scripts)
  - [Dry Run](#dry-run)
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

Install via Julia's package manager. Two common options:

1) Develop from a local clone (recommended for contributors):

```julia
pkg> dev /path/to/llmaccess.jl
```

2) Add by URL:

```julia
using Pkg
Pkg.add(url="https://gitlab.com/newptcai/llmaccess.jl.git")
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
- `Z_API_KEY` for Z.ai

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
export DEEPSEEK_API_KEY="your_deepseek_api_key"
```

To set the default LLM provider and models, add the following lines:

```bash
export DEFAULT_LLM="ollama"
export DEFAULT_OPENAI_MODEL="gpt-5-mini"
export DEFAULT_OPENROUTER_MODEL="amazon/nova-micro-v1"
export DEFAULT_ANTHROPIC_MODEL="claude-3-5-haiku-latest"
export DEFAULT_GOOGLE_MODEL="gemini-2.5-flash"
export DEFAULT_OLLAMA_MODEL="gemma3:4b"
export DEFAULT_MISTRAL_MODEL="mistral-small-latest"
export DEFAULT_GROQ_MODEL="qwen/qwen3-32b"
export DEFAULT_DEEPSEEK_MODEL="deepseek-chat"
# Z.ai default model
export DEFAULT_ZAI_MODEL="glm-4.5-air"
# Optional global default temperature (Float64)
export DEFAULT_TEMPERATURE="1.0"
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

## Documentation

The full user and API documentation is available at:

- https://newptcai.gitlab.io/llmaccess.jl/

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

You may also call by provider name using the convenience signature
`call_llm(llm_name, system_instruction, input_text; model, temperature, copy, think, dry_run)`. Note: the
name-based form does not accept attachments directly; use the typed form (or the CLI) when you need to send an attachment.

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

#### Example: Z.ai

```julia
using LLMAccess

# Create a Z.ai LLM instance
zai_llm = ZaiLLM()

# Define input text and system instructions
input_text = "What is the capital of France?"
system_instruction = "You are concise."

# Call the Z.ai LLM (supports glm-4.5 and glm-4.5-air)
response = call_llm(zai_llm, system_instruction, input_text; model="glm-4.5-air")

println("Z.ai Response: ", response)
```

### Model Aliases

LLMAccess supports shorthand names for common models. Here are some key aliases (including new 1–2 letter shorthands):

| Alias | Full Model Name |
|---|---|
| `ms` | `mistral-small-latest` |
| `m` | `mistral-medium-latest` |
| `ml` | `mistral-large-latest` |
| `mo` | `mistral-ocr-latest` |
| `small` | `mistral-small-latest` |
| `medium` | `mistral-medium-latest` |
| `large` | `mistral-large-latest` |
| `ocr` | `mistral-ocr-latest` |
| `g` | `gemini-2.5-pro` |
| `gf` | `gemini-2.5-flash` |
| `gemini` | `gemini-2.5-pro` |
| `flash` | `gemini-2.5-flash` |
| `s` | `claude-sonnet-4-20250514` |
| `o` | `claude-opus-4-1-20250805` |
| `h` | `claude-3-5-haiku-latest` |
| `sonnet` | `claude-sonnet-4-20250514` |
| `opus` | `claude-opus-4-1-20250805` |
| `haiku` | `claude-3-5-haiku-latest` |
| `magistral` | `magistral-medium-latest` |
| `r` | `deepseek-reasoner` |
| `d` | `deepseek-chat` |
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

Additional popular aliases by provider

- OpenAI (`--llm openai`)
  - `o1`, `o1-mini`, `o1-pro`, `o3`, `o3-mini`, `o3-mini-high`, `o4-mini`
  - `4.1`, `4.1-mini`, `4.1-nano`, `4o-audio`, `4o-rt`, `4o-search`, `4o-mini-search`, `4o-transcribe`
  - `5-chat`, `5-nano`
- Google (`--llm google`)
  - `pro` (Gemini 2.5 Pro), `flash-lite` (Gemini 2.5 Flash Lite)
  - `1.5-pro`, `1.5-flash`, `1.5-flash-8b`, `2.0-flash`
  - `gemma3-4b`, `gemma3-12b`, `gemma3-27b`
  - Media: `imagen-4`, `veo2`
- Anthropic (`--llm anthropic`)
  - `sonnet-3.7`, `sonnet-3.5`, `haiku-3.5`, `opus-4`, `opus-4.1`
- Mistral (`--llm mistral`)
  - Families: `codestral`, `codestral-2508`, `pix` (Pixtral 12B), `pix-large`, `saba`
  - Sizes: `ministral-3b`, `ministral-8b`
  - Dev/Magistral: `devstral-s`, `devstral-m`, `mag-s`, `mag-m`
- Groq (`--llm groq`)
  - `llama-70b`, `llama-8b`, `qwen-32b`, `qwen-14b`, `qwen-8b`, `whisper`, `whisper-turbo`, `r1-70b`, `r1-8b`
- OpenRouter (`--llm openrouter`)
  - `grok-4`, `grok-3`, `grok-3-mini`, `kimi-k2`, `kimi-dev-72b`, `glm-4.5`, `glm-4.5v`, `glm-4.5-air`, `command-r`, `command-r+`, `sonar-pro`, `sonar-reason`, `nova-micro`, `nova-lite`, `nova-pro`, `gemma3-27b-or`
- Ollama (`--llm ollama`)
  - `gemma3-4b-ollama`, `gemma3-12b-ollama`, `qwen3-14b-ollama`, `phi4-r`, `gemma3n-e4b`, `gemma3n-e2b`, `oss-120b`

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

LLMAccess ships with runnable scripts and shared CLI helpers: `parse_commandline` for consistent flags and `run_cli` for robust error handling (usage errors, Ctrl+C, debug traces).

- `script/ask.jl`: General-purpose Q&A.
- `script/cmd.jl`: Generate bash commands (prints, copies to clipboard, and can execute after confirmation). Also supports `--cmd CMD` to bypass the LLM.
- `script/echo.jl`: Echo utility for validating responses.

Examples:

```bash
# Default provider (google)
julia --project script/ask.jl "What is 2+2?"

# OpenAI with model alias
julia --project script/ask.jl --llm openai --model 4o "Summarize this repo"

# Generate shell commands
julia --project script/cmd.jl --llm openai "list files changed today"

# Bypass the LLM and still get copy/execute flow
julia --project script/cmd.jl --cmd 'echo hi'

# Vision with attachments
julia --project script/ask.jl --llm openai --model 4o --attachment ~/Downloads/example.webp "What's in this picture?"
```

#### Mistral OCR

Use Mistral's OCR models with the dedicated endpoint by selecting `mistral-ocr-latest` (or the alias `ocr`). An attachment is required.

```bash
# Dry run (inspect JSON payload only)
julia --project script/ask.jl --llm mistral --model ocr --attachment ./page.jpg -D "extract"

# Real request
julia --project script/ask.jl --llm mistral --model ocr --attachment ./page.jpg "extract"
```

Notes:
- Routes to `https://api.mistral.ai/v1/ocr` with `document.image_url` as a `data:` URL.
- Ignores system instruction and temperature.
- Prefers `pages[*].markdown` in the response; falls back to text fields.

Common arguments:

- `--llm, -l`: LLM provider (`openai`, `anthropic`, `google`, `ollama`, `mistral`, `openrouter`, `groq`, `deepseek`, `zai`). Defaults to `DEFAULT_LLM` or `google`.
- `--model, -m`: Model name; supports aliases below. Defaults to provider’s default.
- `--file, -f`: Path to input file to process (optional; reserved for helpers that consume files).
- `--attachment, -a`: Path to a file to attach (e.g., image for vision APIs).
- `--temperature, -t`: Sampling temperature (default: 1.0).
- `--debug, -d`: Enable debug logging and richer error output.
- `--copy, -c`: Copy response to clipboard.
- `--think, -k`: Enable “thinking” for providers that support it (e.g., Gemini, Claude, Ollama). For Gemini/Claude, this is a token budget (e.g., `-k 1000`). For Ollama, any non-zero enables thinking.
- `--alias, -A`: Print all model aliases and exit.
- `--providers`: Print supported LLM providers (valid `--llm` choices) and exit.
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
- **Z.ai**: OpenAI-compatible API access to GLM-4.5 family.
- **Anthropic**: Utilizes Anthropic's Claude models.
- **Google**: Connects to Google's generative language models.
- **Ollama**: Interfaces with Ollama's local LLM deployments.
- **Mistral**: Access to Mistral's LLM offerings.

You can call providers using typed instances (e.g., `call_llm(GoogleLLM(), ...)`) or by name via `call_llm(llm_name, system_instruction, input_text; model, temperature, copy, think, dry_run)`. The name-based form does not accept attachments; use the typed method or the CLI when you need to include `--attachment`.

## Contributing

Contributions are welcome! If you'd like to contribute to LLMAccess, please fork the repository and create a pull request.

## License

This project is licensed under the [MIT License](LICENSE).
