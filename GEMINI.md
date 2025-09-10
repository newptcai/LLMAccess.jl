# GEMINI.md - Project Overview

This document provides a comprehensive overview of the `LLMAccess.jl` project for AI-powered development.

## Project Overview

`LLMAccess.jl` is a Julia package that provides a unified interface for interacting with various Large Language Model (LLM) APIs. It's designed to be extensible, allowing for the addition of new providers with minimal effort. The project also includes a set of command-line interface (CLI) scripts that leverage the package's functionality for common tasks like asking questions and generating shell commands.

**Key Features:**

*   **Multi-Provider Support:** The package supports multiple LLM providers, including OpenAI, Anthropic, Google, Ollama, and Mistral.
*   **Unified Interface:** A consistent `call_llm` function is used to interact with all supported providers.
*   **CLI Scripts:** The project includes several CLI scripts in the `script/` directory that provide easy access to the package's functionality from the command line.
*   **Extensible Architecture:** The modular design, with separate modules for core functionality, providers, models, and CLI, makes it easy to add new features and providers.

**Technologies:**

*   **Language:** Julia
*   **Key Dependencies:** `ArgParse`, `HTTP`, `JSON`

## Building and Running

### Installation

To install the project and its dependencies, run the following command in the Julia REPL:

```julia
using Pkg
Pkg.add(url="https://gitlab.com/newptcai/llmaccess.jl.git")
```

If you are working from a local clone, you can use `dev` to install the package:

```julia
pkg> dev /path/to/llmaccess.jl
```

Then, instantiate the environment:

```bash
julia --project -e 'using Pkg; Pkg.instantiate()'
```

### Running the CLI Scripts

The CLI scripts are located in the `script/` directory. To run a script, use the `julia` command with the `--project` flag. For example, to run the `ask.jl` script:

```bash
julia --project script/ask.jl "What is the capital of France?"
```

You can specify the LLM provider and model to use with the `--llm` and `--model` flags, respectively:

```bash
julia --project script/ask.jl --llm openai --model 4o "Summarize this repo"
```

### Running Tests

The project includes a test suite in the `test/` directory. To run the tests, you can use the Julia package manager:

```julia
using Pkg
Pkg.test("LLMAccess")
```

Or from the shell:

```bash
julia --project -e 'using Pkg; Pkg.test()'
```

## Development Conventions

*   **Code Style:** The code follows standard Julia conventions.
*   **Modularity:** The project is organized into several modules, each with a specific responsibility. This makes the code easier to understand, maintain, and extend.
*   **Error Handling:** The `run_cli` function in `src/cli.jl` provides centralized error handling for the CLI scripts.
*   **Testing:** The project has a test suite in `test/runtests.jl`. New features should be accompanied by corresponding tests.
