module LLMAccess

using HTTP
using JSON
using ArgParse
using Base64
using MIMEs
using Logging
using Serialization

export call_llm, get_llm_type, parse_commandline

# Abstract Types

"""
    AbstractLLM

An abstract type representing any Large Language Model (LLM).
"""
abstract type AbstractLLM end

"""
    OpenAICompatibleLLM

An abstract type for LLMs that are compatible with OpenAI's API.
"""
abstract type OpenAICompatibleLLM <: AbstractLLM end

# Concrete Types

"""
    OpenAILLM

Concrete type for OpenAI's LLM.
"""
struct OpenAILLM <: OpenAICompatibleLLM end

"""
    OpenRouterLLM

Concrete type for OpenRouter's LLM.
"""
struct OpenRouterLLM <: OpenAICompatibleLLM end

"""
    GroqLLM

Concrete type for Groq's LLM.
"""
struct GroqLLM <: OpenAICompatibleLLM end

"""
    AnthropicLLM

Concrete type for Anthropic's LLM.
"""
struct AnthropicLLM <: AbstractLLM end

"""
    GoogleLLM

Concrete type for Google's LLM.
"""
struct GoogleLLM <: AbstractLLM end

"""
    OllamaLLM

Concrete type for Ollama's LLM.
"""
struct OllamaLLM <: AbstractLLM end

"""
    MistralLLM

Concrete type for Mistral's LLM.
"""
struct MistralLLM <: AbstractLLM end

# Constants

const DEFAULT_MODELS = Dict(
    "openai" => "gpt-4o-mini",
    "openrouter" => "amazon/nova-micro-v1",
    "anthropic" => "claude-3-5-haiku-latest",
    "google" => "gemini-2.0-flash",
    "ollama" => "llama3.2",
    "mistral" => "mistral-small-latest",
    "groq" => "llama-3.3-70b-versatile",
)

const DEFAULT_TEMPERATURE = 0.7
const DEFAULT_LLM = "google"

# Helper Functions

"""
    get_default_llm()

Returns the default LLM provider, determined by the environment variable DEFAULT_LLM or a hard-coded fallback of "$DEFAULT_LLM".
"""
function get_default_llm()
    return get(ENV, "DEFAULT_LLM", DEFAULT_LLM)
end

"""
    get_default_model(llm_name)

Returns the default model for the given provider, determined by the environment variable <PROVIDER>_DEFAULT_MODEL (in uppercase) or a hard-coded fallback in DEFAULT_MODELS.
"""
function get_default_model(llm_name::String)
    return get(ENV, "DEFAULT_"*uppercase(llm_name)*"_MODEL", DEFAULT_MODELS[llm_name])
end

"""
    encode_file_to_base64(file_path)

Encodes the content of a file to a Base64 string along with its MIME type.

# Arguments
- `file_path`: Path to the file to be encoded.

# Returns
A tuple containing the MIME type and the Base64-encoded string.
"""
function encode_file_to_base64(file_path)
    @debug "Encoding $file_path to Base64"

    # Read the file content
    file_content = read(file_path)

    @debug "File content read: $(length(file_content)) bytes"

    # Determine the MIME type based on file extension
    file_extension = splitext(file_path)[2]
    mime_type = mime_from_extension(file_extension)

    @debug "MIME type: $mime_type"

    # Create a base64-encoded string
    io = IOBuffer()
    iob64_encode = Base64EncodePipe(io)
    write(iob64_encode, file_content)
    close(iob64_encode)
    base64_encoded = String(take!(io))

    @debug "Base64 encoded: $(length(base64_encoded)) bytes"

    return (mime_type, base64_encoded)
end

"""
    encode_file_to_base64(llm, file_path)

Overloaded method to encode a file to Base64 based on the LLM type.

# Arguments
- `llm`: An instance of an LLM type.
- `file_path`: Path to the file to be encoded.

# Returns
A dictionary with the encoded image data tailored to the specific LLM.
"""
function encode_file_to_base64(::Union{OpenAICompatibleLLM, MistralLLM}, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)

    return Dict(
        "type" => "image_url",
        "image_url" => Dict("url" => "data:$(mime_type);base64,$base64_encoded"),
    )
end

function encode_file_to_base64(::GoogleLLM, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)

    return Dict(
        "inline_data" => Dict("mime_type" => "$(mime_type)", "data" => "$(base64_encoded)"),
    )
end

function encode_file_to_base64(::AnthropicLLM, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)

    return Dict(
        "type" => "image",
        "source" => Dict("type" => "base64", "media_type" => "$(mime_type)", "data" => "$(base64_encoded)"),
    )
end

"""
    send_request(url, headers, payload)

Sends an HTTP POST request and handles potential errors.

# Arguments
- `url`: The endpoint URL.
- `headers`: HTTP headers to include in the request.
- `payload`: The JSON-serializable data to send in the request body.

# Returns
The HTTP response if successful; otherwise, `nothing`.
"""
function send_request(url, headers, payload)
    try
        @debug "Payload" payload
        temp = "/tmp/payload.jls"
        @debug "Saving payload to $temp"
        serialize(temp, payload)
        @debug "Payload saved"
        json_payload = JSON.json(payload)
        @debug "JSON payload ready"
        response = HTTP.request("POST", url, headers, json_payload, proxy=ENV["http_proxy"])

        if response.status == 200
            return response
        else
            @error "Request failed with status: $(response.status)"
            println(String(response.body))
            return nothing
        end
    catch http_error
        @error "HTTP request error: $http_error"
        return nothing
    end
end

"""
    handle_json_response(response, extraction_path)

Processes the JSON response and extracts the desired data.

# Arguments
- `response`: The HTTP response object.
- `extraction_path`: An array representing the path to the desired data in the JSON structure.

# Returns
The extracted data if successful; otherwise, `nothing`.
"""
function handle_json_response(response, extraction_path)
    if response.status == 200
        try
            response_data = JSON.parse(String(response.body))
            extracted_data = get_nested(response_data, extraction_path)
            return extracted_data
        catch error
            if error isa KeyError
                @error "Failed to extract data: $error"
            else
                @error "Failed to parse JSON response: $error"
            end
            return nothing
        end
    else
        @error "Request failed with status: $(response.status)"
        println(String(response.body))
        return nothing
    end
end

"""
    get_nested(data, path)

Navigates a nested dictionary to retrieve a value.

# Arguments
- `data`: The nested dictionary.
- `path`: An array of keys representing the path to the desired value.

# Returns
The value located at the specified path.
"""
function get_nested(data, path)
    for key in path
        data = data[key]
    end
    return data
end

# LLM Interaction Functions

"""
    call_llm(llm, input_text, system_instruction, model, temperature, attach_file)

Abstract method to call an LLM. Must be implemented for each concrete LLM type.

# Arguments
- `llm`: An instance of an LLM type.
- `input_text`: The input text to send to the LLM.
- `system_instruction`: System-level instructions for the LLM.
- `model`: The specific model to use.
- `temperature`: Sampling temperature for text generation.
- `attach_file`: Path to a file to attach to the request.

# Returns
The response from the LLM.
"""
function call_llm(llm::AbstractLLM, args...)
    error("Not implemented for $(typeof(llm))")
end

"""
    make_api_request(llm, api_key, url, input_text, system_instruction, model, temperature, attach_file)

Prepares and sends an API request for OpenAI-compatible LLMs.

# Arguments
- `llm`: An instance of an OpenAI-compatible LLM.
- `api_key`: API key for authentication.
- `url`: The API endpoint URL.
- `input_text`: The input text to send.
- `system_instruction`: System-level instructions.
- `model`: The specific model to use.
- `temperature`: Sampling temperature.
- `attach_file`: Path to a file to attach.

# Returns
The response from the LLM.
"""
function make_api_request(
    llm::OpenAICompatibleLLM,
    api_key,
    url,
    input_text,
    system_instruction,
    model,
    temperature,
    attach_file,
)
    @debug "Making API request" llm, input_text, system_instruction, model, temperature, attach_file

    headers = ["Content-Type" => "application/json", "Authorization" => "Bearer $api_key"]

    text_data = Dict("type" => "text", "text" => input_text)
    content = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    @debug "API request content" content

    user_message = Dict("role" => "user", "content" => content)
    system_message = Dict("role" => "system", "content" => system_instruction)

    if system_instruction == ""
        messages = [user_message]
    else
        messages = [system_message, user_message]
    end

    data = Dict(
        "model" => model,
        "temperature" => temperature,
        "messages" => messages,
    )

    @debug "API request data" data

    response = send_request(url, headers, data)
    return handle_json_response(response, ["choices", 1, "message", "content"])
end

# Specific LLM Implementations

"""
    call_llm(llm::OpenAILLM, input_text, system_instruction, model, temperature, attach_file)

Calls the OpenAI API with the provided parameters.

# Arguments
- `llm::OpenAILLM`: Instance of OpenAILLM.
- `input_text`: The input text to send.
- `system_instruction`: System-level instructions.
- `model`: The specific model to use.
- `temperature`: Sampling temperature.
- `attach_file`: Path to a file to attach.

# Returns
The response from OpenAI's API.
"""
function call_llm(
    llm::OpenAILLM,
    input_text::String,
    system_instruction::String = "",
    model::String = get(ENV, "OPENAI_DEFAULT_MODEL", DEFAULT_MODELS["openai"]),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    api_key = ENV["OPENAI_API_KEY"]
    url = "https://api.openai.com/v1/chat/completions"
    return make_api_request(
        llm,
        api_key,
        url,
        input_text,
        system_instruction,
        model,
        temperature,
        attach_file,
    )
end

"""
    call_llm(llm::OpenRouterLLM, input_text, system_instruction, model, temperature, attach_file)

Calls the OpenRouter API with the provided parameters.

# Arguments
- `llm::OpenRouterLLM`: Instance of OpenRouterLLM.
- `input_text`: The input text to send.
- `system_instruction`: System-level instructions.
- `model`: The specific model to use.
- `temperature`: Sampling temperature.
- `attach_file`: Path to a file to attach.

# Returns
The response from OpenRouter's API.
"""
function call_llm(
    llm::OpenRouterLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = get(ENV, "OPENROUTER_DEFAULT_MODEL", DEFAULT_MODELS["openrouter"]),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    api_key = ENV["OPENROUTER_API_KEY"]
    url = "https://openrouter.ai/api/v1/chat/completions"
    return make_api_request(
        llm,
        api_key,
        url,
        input_text,
        system_instruction,
        model,
        temperature,
        attach_file,
    )
end

"""
    call_llm(llm::GroqLLM, input_text, system_instruction, model, temperature, attach_file)

Calls the Groq API with the provided parameters.

# Arguments
- `llm::GroqLLM`: Instance of GroqLLM.
- `input_text`: The input text to send.
- `system_instruction`: System-level instructions.
- `model`: The specific model to use.
- `temperature`: Sampling temperature.
- `attach_file`: Path to a file to attach.

# Returns
The response from Groq's API.
"""
function call_llm(
    llm::GroqLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = get(ENV, "GROQ_DEFAULT_MODEL", DEFAULT_MODELS["groq"]),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    api_key = ENV["GROQ_API_KEY"]
    url = "https://api.groq.com/openai/v1/chat/completions"
    if attach_file != ""
        # Groq does not allow attachment and system instructions to be in the
        # same message
        sys_instruction = ""
    else
        sys_instruction = system_instruction
    end

    return make_api_request(
        llm,
        api_key,
        url,
        input_text,
        sys_instruction,
        model,
        temperature,
        attach_file,
    )
end

"""
    call_llm(llm::AnthropicLLM, input_text, system_instruction, model, temperature, attach_file)

Calls the Anthropic API (Claude) with the provided parameters.

# Arguments
- `llm::AnthropicLLM`: Instance of AnthropicLLM.
- `input_text`: The input text to send.
- `system_instruction`: System-level instructions.
- `model`: The specific model to use.
- `temperature`: Sampling temperature.
- `attach_file`: Path to a file to attach.

# Returns
The response from Anthropic's API.
"""
function call_llm(
    llm::AnthropicLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = get(ENV, "ANTHROPIC_DEFAULT_MODEL", DEFAULT_MODELS["anthropic"]),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    api_key = ENV["ANTHROPIC_API_KEY"]
    url = "https://api.anthropic.com/v1/messages"

    headers = [
        "content-type" => "application/json",
        "anthropic-version" => "2023-06-01",
        "x-api-key" => "$api_key",
    ]

    text_data = Dict("type" => "text", "text" => input_text)
    content = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    data = Dict(
        "model" => model,
        "max_tokens" => 1024,
        "temperature" => temperature,
        "system" => system_instruction,
        "messages" => [Dict("role" => "user", "content" => content)],
    )
    response = send_request(url, headers, data)

    return handle_json_response(response, ["content", 1, "text"])
end

"""
    call_llm(llm::GoogleLLM, input_text, system_instruction, model, temperature, attach_file)

Calls the Google API with the provided parameters.

# Arguments
- `llm::GoogleLLM`: Instance of GoogleLLM.
- `input_text`: The input text to send.
- `system_instruction`: System-level instructions.
- `model`: The specific model to use.
- `temperature`: Sampling temperature.
- `attach_file`: Path to a file to attach.

# Returns
The response from Google's API.
"""
function call_llm(
    llm::GoogleLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = get(ENV, "GOOGLE_DEFAULT_MODEL", DEFAULT_MODELS["google"]),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    @debug "Making API request" llm input_text system_instruction model temperature attach_file

    api_key = ENV["GOOGLE_API_KEY"]
    url = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key"

    headers = ["Content-Type" => "application/json"]

    text_data = Dict("text" => input_text)
    parts = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    data = Dict(
        "system_instruction" => Dict("parts" => Dict("text" => system_instruction)),
        "generationConfig" => Dict("temperature" => temperature),
        "contents" => Dict("parts" => parts),
    )

    response = send_request(url, headers, data)
    return handle_json_response(response, ["candidates", 1, "content", "parts", 1, "text"])
end

"""
    call_llm(llm::OllamaLLM, input_text, system_instruction, model, temperature)

Calls the Ollama API with the provided parameters.

# Arguments
- `llm::OllamaLLM`: Instance of OllamaLLM.
- `input_text`: The input text to send.
- `system_instruction`: System-level instructions.
- `model`: The specific model to use.
- `temperature`: Sampling temperature.
- `attach_file`: Path to a file to attach.

# Returns
The response from Ollama's API.
"""
function call_llm(
    llm::OllamaLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = get(ENV, "OLLAMA_DEFAULT_MODEL", DEFAULT_MODELS["ollama"]),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    @debug "Making API request" llm input_text system_instruction model temperature attach_file

    url = "http://127.0.0.1:11434/api/generate"

    headers = ["Content-Type" => "application/json"]

    data = Dict(
        "model" => model,
        "prompt" => input_text,
        "stream" => false,
        "system" => system_instruction,
        "options" => Dict("temperature" => temperature),
    )

    response = send_request(url, headers, data)
    return handle_json_response(response, ["response"])
end

"""
    call_llm(llm::MistralLLM, input_text, system_instruction, model, temperature, attach_file)

Calls the Mistral API with the provided parameters.

# Arguments
- `llm::MistralLLM`: Instance of MistralLLM.
- `input_text`: The input text to send.
- `system_instruction`: System-level instructions.
- `model`: The specific model to use.
- `temperature`: Sampling temperature.
- `attach_file`: Path to a file to attach.

# Returns
The response from Mistral's API.
"""
function call_llm(
    llm::MistralLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = get(ENV, "MISTRAL_DEFAULT_MODEL", DEFAULT_MODELS["mistral"]),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    @debug "Making API request" llm input_text system_instruction model temperature attach_file

    api_key = ENV["MISTRAL_API_KEY"]
    url = "https://api.mistral.ai/v1/chat/completions"

    headers = [
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "Authorization" => "Bearer $api_key",
    ]

    text_data = Dict("type" => "text", "text" => input_text)
    content = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    data = Dict(
        "model" => model,
        "temperature" => temperature,
        "messages" => [
            Dict("role" => "system", "content" => system_instruction),
            Dict("role" => "user", "content" => content),
        ],
    )

    response = send_request(url, headers, data)
    return handle_json_response(response, ["choices", 1, "message", "content"])
end

"""
    get_llm_type(llm_name)

Retrieves the LLM type based on a string identifier.

# Arguments
- `llm_name`: The name of the LLM provider.

# Returns
An instance of the corresponding LLM type.

# Errors
Throws an error if the `llm_name` is unknown.
"""
function get_llm_type(llm_name::String)
    llm_types = Dict(
        "openai" => OpenAILLM(),
        "anthropic" => AnthropicLLM(),
        "google" => GoogleLLM(),
        "ollama" => OllamaLLM(),
        "mistral" => MistralLLM(),
        "openrouter" => OpenRouterLLM(),
        "groq" => GroqLLM(),
    )
    get(llm_types, llm_name) do
        error("Unknown LLM: $llm_name")
    end
end

"""
    call_llm(llm_name, input_text, system_instruction, model, temperature)

Selects the appropriate LLM based on the provider name and invokes it.

# Arguments
- `llm_name`: The name of the LLM provider.
- `input_text`: The input text to send.
- `system_instruction`: System-level instructions.
- `model`: The specific model to use (optional).
- `temperature`: Sampling temperature.

# Returns
The response from the selected LLM.
"""
function call_llm(
    llm_name::String,
    input_text::String,
    system_instruction::String,
    model::String = "",
    temperature::Float64 = DEFAULT_TEMPERATURE,
)
    llm_type = get_llm_type(llm_name)
    selected_model = isempty(model) ? get(ENV, uppercase(llm_name)*"_DEFAULT_MODEL", DEFAULT_MODELS[llm_name]) : model

    result = call_llm(llm_type, input_text, system_instruction, selected_model, temperature)
    println(result)
end

"""
    create_default_settings()

Creates the default ArgParse settings for command-line argument parsing.

# Returns
An `ArgParseSettings` object with default configurations.
"""
function create_default_settings()
    return ArgParseSettings(
        description = "Process text using various LLM providers.",
        add_version = true,
    )
end

"""
    parse_commandline(settings; require_input=true)

Parses command-line arguments for the LLM script with no explicit default LLM or model.

# Arguments
- `settings::ArgParseSettings`: The argument parsing settings.
- `require_input::Bool`: Whether input text is required (default: `true`).

# Behaviour
- The default LLM provider is determined using `get_default_llm()`.
- The default model is inferred using `get_default_model(llm)`.
- Calls `parse_commandline(settings, llm, model; require_input=require_input)` internally.

# Returns
A dictionary containing parsed command-line arguments.
"""
function parse_commandline(
    settings::ArgParseSettings = create_default_settings();
    require_input::Bool = true
)
    llm   = get_default_llm()
    model = get_default_model(llm)
    return parse_commandline(settings, llm, model; require_input=require_input)
end

"""
    parse_commandline(settings, default_llm; require_input=true)

Parses command-line arguments for the LLM script when the default LLM provider is specified.

# Arguments
- `settings::ArgParseSettings`: The argument parsing settings.
- `default_llm::String`: The default LLM provider to use.
- `require_input::Bool`: Whether input text is required (default: `true`).

# Behaviour
- The default model is inferred using `get_default_model(default_llm)`.
- Calls `parse_commandline(settings, default_llm, default_model; require_input=require_input)` internally.

# Returns
A dictionary containing parsed command-line arguments.
"""
function parse_commandline(
    settings::ArgParseSettings,
    default_llm::String;
    require_input::Bool = true
)
    default_model = get_default_model(default_llm)
    return parse_commandline(settings, default_llm, default_model; require_input=require_input)
end

"""
    parse_commandline(settings, default_llm, default_model; require_input=true)

Parses command-line arguments for the LLM script when both the default LLM provider and model are specified.

# Arguments
- `settings::ArgParseSettings`: The argument parsing settings.
- `default_llm::String`: The default LLM provider to use.
- `default_model::String`: The specific model to use.
- `require_input::Bool`: Whether input text is required (default: `true`).

# Behaviour
- Uses `ArgParse` to define command-line arguments for selecting the LLM provider, model, input file, attachments, generation parameters, and debug mode.
- If `require_input` is `true` and no input text is provided, it reads from `stdin`.
- If LLM or model is not specified by the user, it defaults to `default_llm` and `default_model`.
- Enables debug mode if `--debug` is passed.

# Returns
A dictionary containing parsed command-line arguments.
"""
function parse_commandline(
    settings::ArgParseSettings,
    default_llm::String,
    default_model::String;
    require_input::Bool = true
)
    @add_arg_table! settings begin
        "--llm", "-l"
        help = "LLM provider to use"
        default = default_llm

        "--model", "-m"
        help = "Specific model to use"
        default = default_model

        "--file", "-f"
        help = "Path to the file to process"
        default = ""

        "--attachment", "-a"
        help = "Path to the file to attach"
        default = ""

        "--temperature", "-t"
        help = "Temperature for text generation"
        arg_type = Float64
        default = 0.7  # replace with your DEFAULT_TEMPERATURE

        "--debug", "-d"
        help = "Enable debug mode"
        action = :store_true

        "input_text"
        help = "Input text for the LLM (reads from stdin if not provided)"
        required = false
    end

    args = parse_args(settings)

    if isnothing(args["input_text"]) && require_input
        args["input_text"] = read(stdin, String)
    end

    # Check if llm is specified by the user but not model
    # If so, use default model for the given llm
    if args["llm"] != default_llm && args["model"] == default_model
        args["model"] = get_default_model(args["llm"])
    end

    if args["debug"]
        global_logger(ConsoleLogger(stderr, Logging.Debug))
        @info "Debug mode enabled"
    end

    return args
end

end # module LLMAccess
