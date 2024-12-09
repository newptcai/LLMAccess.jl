module LLMAccess

using HTTP
using JSON
using ArgParse
using Base64
using MIMEs

export call_llm, get_llm_type, parse_commandline

# Abstract type for all LLMs
abstract type AbstractLLM end

# Abstract type for OpenAI-compatible LLMs
abstract type OpenAICompatibleLLM <: AbstractLLM end

# Concrete types for each LLM provider
struct OpenAILLM <: OpenAICompatibleLLM end
struct OpenRouterLLM <: OpenAICompatibleLLM end
struct GroqLLM <: OpenAICompatibleLLM end
struct AnthropicLLM <: AbstractLLM end
struct GoogleLLM <: AbstractLLM end
struct OllamaLLM <: AbstractLLM end
struct MistralLLM <: AbstractLLM end

# Default models and temperature
DEFAULT_MODELS = Dict(
    "openai" => "gpt-4o-mini",
    "openrouter" => "amazon/nova-micro-v1",
    "anthropic" => "claude-3-5-haiku-latest",
    "google" => "gemini-1.5-flash-latest",
    "ollama" => "llama3.2",
    "mistral" => "mistral-small-latest",
    "groq" => "llama-3.3-70b-versatile",
)
const DEFAULT_TEMPERATURE = 0.7

function encode_file_to_base64(file_path)
    # Read the file content
    file_content = read(file_path)

    # Determine the MIME type based on file extension
    file_extension = splitext(file_path)[2]
    mime_type = mime_from_extension(file_extension)

    # Create a base64-encoded string
    io = IOBuffer()
    iob64_encode = Base64EncodePipe(io)
    write(iob64_encode, file_content)
    close(iob64_encode)
    base64_encoded = String(take!(io))

    return (mime_type, base64_encoded)
end

function encode_file_to_base64(::Union{OpenAICompatibleLLM,MistralLLM}, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)

    # Construct the dictionary with the encoded string
    return Dict(
        "type" => "image_url",
        "image_url" => Dict("url" => "data:$(mime_type);base64,$base64_encoded"),
    )
end

function encode_file_to_base64(::GoogleLLM, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)

    # Construct the dictionary with the encoded string
    return Dict(
        "inline_data" => Dict("mime_type"=>"$(mime_type)", "data"=>"$(base64_encoded)"),
    )
end

function encode_file_to_base64(::AnthropicLLM, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)

    # Construct the dictionary with the encoded string
    return Dict(
        "type" => "image",
        "source" =>
            Dict("type"=>"base64", "media_type"=>"$(mime_type)", "data"=>"$(base64_encoded)"),
    )
end

# Function to send request and handle errors
function send_request(url, headers, data)
    try
        # Convert data to JSON
        json_data = JSON.json(data)

        # Send the POST request to Google's API
        response = HTTP.request("POST", url, headers, json_data, proxy = ENV["http_proxy"])

        # Check if the request was successful
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

# Function to handle JSON responses
function handle_json_response(response, extraction_path)
    if response.status == 200
        try
            # Parse the JSON response
            response_data = JSON.parse(String(response.body))

            # Use the extraction path to get the output
            output_text = get_nested(response_data, extraction_path)

            return output_text
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

# Helper function to navigate nested dictionaries
function get_nested(data, path)
    for key in path
        data = data[key]
    end
    return data
end

# Generic call_llm function
function call_llm(llm::AbstractLLM, args...)
    error("Not implemented for $(typeof(llm))")
end

# Specific implementations

# Function to make the API request for OpenAI compatible services
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
    # Set headers
    headers = ["Content-Type" => "application/json", "Authorization" => "Bearer $api_key"]

    # Prepare content
    text_data = Dict("type" => "text", "text" => input_text)
    if attach_file != ""
        image_data = encode_file_to_base64(llm, attach_file)
        content = [text_data, image_data]
    else
        content = [text_data]
    end

    # Prepare the request data
    data = Dict(
        "model" => model,
        "temperature" => temperature,
        "messages" => [
            Dict("role" => "system", "content" => system_instruction),
            Dict("role" => "user", "content" => content),
        ],
    )

    # Send the request
    response = send_request(url, headers, data)

    # Handle the response
    return handle_json_response(response, ["choices", 1, "message", "content"])
end

# Function to call OpenAI API
function call_llm(
    llm::OpenAILLM,
    input_text::String,
    system_instruction::String = "",
    model::String = DEFAULT_MODELS["openai"],
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    # Set API key and URL
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

# Function to call OpenRouter API (example of another OpenAI compatible API)
function call_llm(
    llm::OpenRouterLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = DEFAULT_MODELS["openrouter"],
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    # Set API key and URL
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

# Function to call Groq API
function call_llm(
    llm::GroqLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = DEFAULT_MODELS["openai"],
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    # Set API key and URL
    api_key = ENV["GROQ_API_KEY"]
    url = "https://api.groq.com/openai/v1/chat/completions"
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

# Function to call Anthropic API (Claude)
function call_llm(
    llm::AnthropicLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = DEFAULT_MODELS["anthropic"],
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    # Set API key and URL
    api_key = ENV["ANTHROPIC_API_KEY"]
    url = "https://api.anthropic.com/v1/messages"

    # Set headers
    headers = [
        "content-type" => "application/json",
        "anthropic-version" => "2023-06-01",
        "x-api-key" => "$api_key",
    ]

    # Prepare content
    text_data = Dict("type" => "text", "text" => input_text)
    if attach_file != ""
        image_data = encode_file_to_base64(llm, attach_file)
        content = [text_data, image_data]
    else
        content = [text_data]
    end

    # Prepare the request data
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

# Function to call Google API
function call_llm(
    llm::GoogleLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = DEFAULT_MODELS["google"],
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)
    # Set API key and URL
    api_key = ENV["GOOGLE_API_KEY"]
    url = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key"

    # Set headers
    headers = ["Content-Type" => "application/json"]

    # Prepare parts
    text_data = Dict("text" => input_text)
    if attach_file != ""
        image_data = encode_file_to_base64(llm, attach_file)
        parts = [text_data, image_data]
    else
        parts = [text_data]
    end

    # Prepare the request data
    data = Dict(
        "system_instruction" => Dict("parts" => Dict("text" => system_instruction)),
        "generationConfig" => Dict("temperature" => temperature),
        "contents" => Dict("parts" => parts),
    )

    response = send_request(url, headers, data)

    return handle_json_response(response, ["candidates", 1, "content", "parts", 1, "text"])
end

# Function to call Ollama API
function call_llm(
    ::OllamaLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = DEFAULT_MODELS["ollama"],
    temperature::Float64 = DEFAULT_TEMPERATURE,
)

    # Set URL
    url = "http://127.0.0.1:11434/api/generate"

    # Set headers
    headers = ["Content-Type" => "application/json"]

    # Prepare the request data
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

# Function to call Mistral API
function call_llm(
    llm::MistralLLM,
    input_text::String,
    system_instruction::String = "",
    model::String = DEFAULT_MODELS["mistral"],
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file::String = "",
)

    # Set URL and API key
    url = "https://api.mistral.ai/v1/chat/completions"
    api_key = ENV["MISTRAL_API_KEY"]

    # Set headers
    headers = [
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "Authorization" => "Bearer $api_key",
    ]

    # Prepare content
    text_data = Dict("type" => "text", "text" => input_text)
    if attach_file != ""
        image_data = encode_file_to_base64(llm, attach_file)
        content = [text_data, image_data]
    else
        content = [text_data]
    end

    # Prepare the request data
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

# Function to get LLM type from string
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

# Function to select LLM and call corresponding model
function call_llm(
    llm::String,
    input_text::String,
    system_instruction::String,
    model::String = "",
    temperature::Float64 = DEFAULT_TEMPERATURE,
)
    llm_type = get_llm_type(llm)
    model = (model == "" ? DEFAULT_MODELS[llm] : model)

    result = call_llm(llm_type, input_text, system_instruction, model, temperature)
    println(result)
end

# Create default ArgParseSettings
function create_default_settings()
    return ArgParseSettings(
        description = "Process text using various LLM providers.",
        add_version = true,
    )
end

# Parse command-line arguments
function parse_commandline(
    s::ArgParseSettings = create_default_settings(),
    default_llm::String = "google",
    default_model::String = "",
    require_input_text::Bool = true,
)
    @add_arg_table s begin
        "--llm", "-l"
        help = "LLM provider to use (openai, anthropic, google, ollama, mistral, openrouter)"
        default = default_llm
        "--model", "-m"
        help = "Specific model to use (optional)"
        default = ""
        "--file", "-f"
        help = "Specific the path to the file to process (optional)"
        default = ""
        "--attachment", "-a"
        help = "Specific the path to the file to be attached to the request (optional)"
        default = ""
        "--temperature", "-t"
        help = "Temperature for text generation"
        arg_type = Float64
        default = 0.7  # Assuming DEFAULT_TEMPERATURE is 0.7
        "--debug", "-d"
        help = "Enable debug mode"
        action = :store_true
        "input_text"
        help = "Input text for the LLM (optional, reads from stdin if not provided)"
        required = false
    end

    args = parse_args(s)

    # If input_text is not provided, read from stdin
    if isnothing(args["input_text"]) && require_input_text
        args["input_text"] = read(stdin, String)
    end

    # Set model if not provided
    if isempty(args["model"])
        args["model"] = DEFAULT_MODELS[args["llm"]]
    end

    # Print args if debug mode is enabled
    if args["debug"]
        println("""
                Calling LLM with:
                -- llm: $(args["llm"])
                -- input_text: $(args["input_text"])
                -- model: $(args["model"])
                -- temperature: $(args["temperature"])
                """)
    end

    return args
end

end # module LLMAccess
