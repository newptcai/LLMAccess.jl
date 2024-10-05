module LLMAccess

using HTTP
using JSON
using ArgParse

export call_llm, get_llm_type, parse_commandline

# Abstract type for all LLMs
abstract type AbstractLLM end

# Concrete types for each LLM provider
struct OpenAILLM <: AbstractLLM end
struct AnthropicLLM <: AbstractLLM end
struct GoogleLLM <: AbstractLLM end
struct OllamaLLM <: AbstractLLM end
struct MistralLLM <: AbstractLLM end

# Default models and temperature
DEFAULT_MODELS = Dict(
    "openai" => "gpt-4o-mini",
    "anthropic" => "claude-3-haiku-20240307",
    "google" => "gemini-1.5-flash",
    "ollama" => "llama3.2",
    "mistral" => "mistral-small-latest"
)
const DEFAULT_TEMPERATURE = 0.7

# Function to send request and handle errors
function send_request(url, headers, data)
    try
        # Convert data to JSON
        json_data = JSON.json(data)

        # Send the POST request to Google's API
        response = HTTP.request("POST", url, headers, json_data)

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
function call_llm(llm::AbstractLLM, input_text::String, system_instruction::String, model::String, temperature::Float64)
    error("Not implemented for $(typeof(llm))")
end

# Specific implementations

# Function to call OpenAI API
function call_llm(::OpenAILLM,
        input_text::String, 
        system_instruction::String="",
        model::String=DEFAULT_MODELS["openai"],
        temperature::Float64=DEFAULT_TEMPERATURE)
    # Set API key and URL
    api_key = ENV["OPENAI_API_KEY"]
    url = "https://api.openai.com/v1/chat/completions"

    # Set headers
    headers = ["Content-Type" => "application/json",
                "Authorization" => "Bearer $api_key"]

    # Prepare the request data
    data = Dict(
        "model" => model,
        "temperature" => temperature,
        "messages" => [
            Dict("role" => "system", "content" => system_instruction),
            Dict("role" => "user", "content" => input_text)
        ]
    )

    response = send_request(url, headers, data)

    return handle_json_response(response, ["choices", 1, "message", "content"])
end

# Function to call Anthropic API (Claude)
function call_llm(::AnthropicLLM,
        input_text::String,
        system_instruction::String="", 
        model::String=DEFAULT_MODELS["anthropic"],
        temperature::Float64=DEFAULT_TEMPERATURE)
    # Set API key and URL
    api_key = ENV["ANTHROPIC_API_KEY"]
    url = "https://api.anthropic.com/v1/messages"

    # Set headers
    headers = ["content-type" => "application/json",
                "anthropic-version" => "2023-06-01",
                "x-api-key" => "$api_key"]

    # Prepare the request data
    data = Dict(
        "model" => model,
        "max_tokens" => 1024,
        "temperature" => temperature,
        "system" => system_instruction,
        "messages" => [
            Dict("role" => "user", "content" => input_text)
        ]
    )
    response = send_request(url, headers, data)

    return handle_json_response(response, ["content", 1, "text"])
end

# Function to call Google API
function call_llm(::GoogleLLM,
        input_text::String, 
        system_instruction::String="",
        model::String=DEFAULT_MODELS["google"],
        temperature::Float64=DEFAULT_TEMPERATURE)
    # Set API key and URL
    api_key = ENV["GOOGLE_API_KEY"]
    url = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key"

    # Set headers
    headers = ["Content-Type" => "application/json"]

    # Prepare the request data
    data = Dict(
        "system_instruction" => Dict(
            "parts" => Dict("text" => system_instruction)
        ),
        "generationConfig" => Dict(
            "temperature" => temperature
        ),
        "contents" => Dict(
            "parts" => Dict("text" => input_text)
        )
    )

    response = send_request(url, headers, data)

    return handle_json_response(response, ["candidates", 1, "content", "parts", 1, "text"])
end

# Function to call Ollama API
function call_llm(::OllamaLLM,
        input_text::String,
        system_instruction::String="",
        model::String=DEFAULT_MODELS["ollama"],
        temperature::Float64=DEFAULT_TEMPERATURE)

    # Set URL
    url = "http://127.0.0.1:11434/api/generate"

    # Set headers
    headers = ["Content-Type" => "application/json"]

    # Prepare the request data
    data = Dict("model" => model, 
                "prompt" => input_text,
                "stream" => false,
                "system" => system_instruction,
                "options" => Dict("temperature" => temperature)
               )

    response = send_request(url, headers, data)

    return handle_json_response(response, ["response"])
end

# Function to call Mistral API
function call_llm(::MistralLLM,
        input_text::String,
        system_instruction::String="",
        model::String=DEFAULT_MODELS["mistral"],
        temperature::Float64=DEFAULT_TEMPERATURE)

    # Set URL and API key
    url = "https://api.mistral.ai/v1/chat/completions"
    api_key = ENV["MISTRAL_API_KEY"]

    # Set headers
    headers = ["Content-Type" => "application/json",
        "Accept" => "application/json",
        "Authorization" => "Bearer $api_key"]

    # Prepare the request data
    data = Dict("model" => model, 
                "temperature" => temperature,
                "messages" => [
                    Dict("role" => "system", "content" => system_instruction),
                    Dict("role" => "user", "content" => input_text)
                ]
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
        "mistral" => MistralLLM()
    )
    get(llm_types, llm_name) do
        error("Unknown LLM: $llm_name")
    end
end

# Function to select LLM and call corresponding model
function call_llm(llm::String,
        input_text::String,
        system_instruction::String,
        model::String="",
        temperature::Float64=DEFAULT_TEMPERATURE)
    llm_type = get_llm_type(llm)
    model = (model == "" ? DEFAULT_MODELS[llm] : model)
    
    result = call_llm(llm_type,
                      input_text, 
                      system_instruction, 
                      model, 
                      temperature)
    println(result)
end

# Create default ArgParseSettings
function create_default_settings()
    return ArgParseSettings(
        description = "Process text using various LLM providers.",
        add_version = true
    )
end

# Parse command-line arguments
function parse_commandline(
        s::ArgParseSettings = create_default_settings(), 
        default_llm::String="google",
        default_model::String="")
    @add_arg_table s begin
        "--llm", "-l"
            help = "LLM provider to use (openai, anthropic, google, ollama, mistral)"
            default = default_llm
        "--model", "-m"
            help = "Specific model to use (optional)"
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
    if isnothing(args["input_text"])
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
