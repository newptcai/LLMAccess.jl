# LLMAccess

LLMAccess is a Julia package designed to simplify interactions with various
Large Language Model (LLM) APIs. Whether you're leveraging OpenAI, Anthropic,
Google, Ollama, Mistral, OpenRouter, or Groq, LLMAccess provides a unified and
straightforward interface to integrate these models into your Julia
scripts seamlessly.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Importing the Module](#importing-the-module)
  - [Calling an LLM](#calling-an-llm)
    - [Example: OpenAI](#example-openai)
    - [Example: Google](#example-google)
  - [Using with Command-Line](#using-with-command-line)
- [Supported LLM Providers](#supported-llm-providers)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Multi-Provider Support**: Interact with multiple LLM providers through a consistent interface.
- **File Attachments**: Easily attach files to your API requests.
- **Command-Line Integration**: Parse command-line arguments for flexible script execution.
- **Extensible Design**: Add support for new LLM providers with minimal effort.
- **Error Handling**: Robust error handling to manage API request failures gracefully.

## Installation

To install LLMAccess, use Julia's package manager. Open your Julia REPL and execute:

```julia
using Pkg
Pkg.add("git@gitlab.com:newptcai/llmaccess.jl.git")
```

## Configuration

Before using LLMAccess, ensure you have the necessary API keys for the LLM providers you intend to use. Set these keys as environment variables in your system:

- `OPENAI_API_KEY` for OpenAI
- `OPENROUTER_API_KEY` for OpenRouter
- `GROQ_API_KEY` for Groq
- `ANTHROPIC_API_KEY` for Anthropic
- `GOOGLE_API_KEY` for Google
- `MISTRAL_API_KEY` for Mistral

### Setting Environment Variables

**On Unix/Linux/macOS:**

Add the following lines to your `.bashrc`, `.zshrc`, or equivalent shell configuration file:

```bash
export OPENAI_API_KEY="your_openai_api_key"
export OPENROUTER_API_KEY="your_openrouter_api_key"
export GROQ_API_KEY="your_groq_api_key"
export ANTHROPIC_API_KEY="your_anthropic_api_key"
export GOOGLE_API_KEY="your_google_api_key"
export MISTRAL_API_KEY="your_mistral_api_key"
```

After adding, reload your shell configuration:

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

Begin by importing the LLMAccess module in your Julia script:

```julia
using LLMAccess
```

### Calling an LLM

LLMAccess provides a flexible `call_llm` function that interacts with the specified LLM provider. You can instantiate the desired LLM type and invoke the function with the required parameters.

#### Example: OpenAI

```julia
using LLMAccess

# Create an OpenAI LLM instance
openai_llm = OpenAILLM()

# Define input text and system instructions
input_text = "Hello, how are you?"
system_instruction = "You are a helpful assistant."

# Call the OpenAI LLM
response = call_llm(openai_llm, input_text, system_instruction)

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
response = call_llm(google_llm, input_text, system_instruction)

println("Google Response: ", response)
```

### Using with Command-Line

LLMAccess includes a `parse_commandline` function to facilitate command-line argument parsing, making it easy to integrate into scripts and automation workflows.

#### Example Script

Create a Julia script named `ask.jl`:

```julia
#!/usr/bin/env julia

using LLMAccess
using ArgParse

function main()
    # Define the system prompt
    system_instruction = """
    Please answer user question as truthfuly as possible.
    Be concise with your answer.
    """

    custom_settings = ArgParseSettings(
        description = "Use LLM to answer simple question.",
        add_version = true,
        version = "v1.0.0",
    )

    args = parse_commandline(custom_settings, "google")

    if args["debug"]
        println("Ready to LLM ...")
    end

    llm_type = get_llm_type(args["llm"])
    result = call_llm(
        llm_type,
        args["input_text"],
        system_instruction,
        args["model"],
        args["temperature"],
        args["attachment"],
    )

    if args["debug"]
        println("LLM output: ...")
    end

    if result !== nothing
        print(result)
        if result[end] != "\n"
            print("\n")
        end
        exit(0)
    else
        @error "Failed to get a valid response from the server."
        exit(1)
    end
end

main()
```

#### Running the Script

Make the script executable:

```bash
chmod +x ask.jl
```

Execute the script with desired arguments:

```bash
./ask.jl --llm openai --model "gpt-4o-latest" --attachment ~/Downloads/example.webp "What's in this picture?" 
```

**Available Command-Line Arguments:**

- `--llm`, `-l`: **(Required)** LLM provider to use (e.g., `openai`, `anthropic`, `google`, `ollama`, `mistral`, `openrouter`, `groq`).
- `--input_text`, `-i`: **(Optional)** Input text for the LLM. If not provided, the script will read from `stdin`.
- `--model`, `-m`: **(Optional)** Specific model to use. If omitted, the default model for the specified LLM will be used.
- `--attachment`, `-a`: **(Optional)** Path to a file to attach to the request.
- `--temperature`, `-t`: **(Optional)** Sampling temperature for text generation (default: `0.7`).
- `--debug`, `-d`: **(Optional)** Enable debug mode to print detailed information.

## Supported LLM Providers

LLMAccess currently supports the following LLM providers:

- **OpenAI**: Access to models like GPT-4, GPT-3.5, etc.
- **OpenRouter**: Compatible with OpenAI's API endpoints.
- **Groq**: Integrates with Groq's LLM services.
- **Anthropic**: Utilizes Anthropic's Claude models.
- **Google**: Connects to Google's generative language models.
- **Ollama**: Interfaces with Ollama's local LLM deployments.
- **Mistral**: Access to Mistral's LLM offerings.

## Contributing

Contributions are welcome! If you'd like to contribute to LLMAccess, please follow these steps:

1. **Fork the Repository**: Click the "Fork" button at the top-right corner of the repository page.
2. **Clone Your Fork**:

    ```bash
    git clone https://github.com/your-username/LLMAccess.git
    cd LLMAccess
    ```

3. **Create a New Branch**:

    ```bash
    git checkout -b feature/your-feature-name
    ```

4. **Make Your Changes**: Implement your feature or bug fix.

5. **Commit Your Changes**:

    ```bash
    git commit -m "Description of your changes"
    ```

6. **Push to Your Fork**:

    ```bash
    git push origin feature/your-feature-name
    ```

7. **Create a Pull Request**: Navigate to the original repository and create a pull request from your fork.

Please ensure your code follows the project's coding standards and includes appropriate tests.

## License

This project is licensed under the [MIT License](LICENSE).
