module LLMAccess

using HTTP
using JSON
using ArgParse
using Base64
using MIMEs
using Logging
using Serialization
using Pandoc
using InteractiveUtils

export call_llm, 
    list_llm_models,
    get_llm_type,
    get_llm_list,
    parse_commandline,
    jina_reader,
    pandoc_reader

# ─────────────────────────────────────────────────────────────────────────────
# Abstract Types
# ─────────────────────────────────────────────────────────────────────────────

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

# ─────────────────────────────────────────────────────────────────────────────
# Concrete Types
# ─────────────────────────────────────────────────────────────────────────────

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

Concrete type for Anthropic's LLM (e.g., Claude).
"""
struct AnthropicLLM <: AbstractLLM end

"""
    GoogleLLM

Concrete type for Google's LLM (e.g., PaLM/Gemini).
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

"""
    DeepSeekLLM

Concrete type for DeepSeek's LLM (OpenAI-compatible API).
"""
struct DeepSeekLLM <: OpenAICompatibleLLM end

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

const DEFAULT_MODELS = Dict(
    "openai"      => "gpt-4o-mini",
    "openrouter"  => "amazon/nova-micro-v1",
    "anthropic"   => "claude-3-5-haiku-latest",
    "google"      => "gemini-2.0-flash",
    "ollama"      => "gemma3:4b",
    "mistral"     => "mistral-small-latest",
    "groq"        => "llama-3.3-70b-versatile",
    "deepseek"    => "deepseek-chat",
)

const DEFAULT_TEMPERATURE = 0.7
const DEFAULT_LLM = "google"

const MODEL_ALIASES = Dict(
    "mistral" => "mistral-large-latest",
    "gemini" => "gemini-2.5-pro-exp-03-25",
    "flash" => "gemini-2.0-flash",
    "gemma" => "gemma3:4b",
    "sonnet" => "claude-3-7-sonnet-20250219",
    "haiku" => "claude-3-5-haiku-latest",
    "r1" => "deepseek-reasoner",
    "v3" => "deepseek-chat",
    "4o" => "gpt-4o",
    "4o-mini" => "gpt-4o-mini",
    "3.5" => "gpt-3.5-turbo",
)

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

"""
    get_default_llm()

Returns the default LLM provider, determined by the environment variable
`DEFAULT_LLM` or a hard-coded fallback (`"$(DEFAULT_LLM)"`).
"""
function get_default_llm()
    return get(ENV, "DEFAULT_LLM", DEFAULT_LLM)
end

"""
    get_llm_list()

Returns the list of LLM provider.
"""
function get_llm_list()
    return keys(DEFAULT_MODELS)
end

"""
    get_default_model(llm_name)

Returns the default model for the given provider, determined by the environment
variable `DEFAULT_<LLM_NAME>_MODEL` (converted to uppercase) or a hard-coded fallback
in `DEFAULT_MODELS`.
"""
function get_default_model(llm_name)
    return get(ENV, "DEFAULT_"*uppercase(llm_name)*"_MODEL", DEFAULT_MODELS[llm_name])
end

"""
    resolve_model_alias(model_name)

Returns the full model name if the given `model_name` is a known alias; 
otherwise returns `model_name` unchanged.
"""
function resolve_model_alias(model_name)
    return get(MODEL_ALIASES, model_name, model_name)
end

"""
    encode_file_to_base64(file_path)

Encodes the content of a file to a Base64 string along with its MIME type.

# Arguments
- `file_path`: Path to the file to be encoded.

# Returns
A tuple `(mime_type::MIME, base64_encoded)` containing the file's MIME type
and its Base64-encoded content.
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

Overloaded method to encode a file to Base64 based on the LLM type. Returns a dictionary
structure that each LLM expects in its request body.

# Arguments
- `llm::Union{OpenAICompatibleLLM, MistralLLM}`: An instance of an LLM compatible
  with the "type=image_url" approach.
- `file_path`: Path to the file to be encoded.

# Returns
A dictionary with the encoded image data, suitable for inclusion in the LLM request.
"""
function encode_file_to_base64(::Union{OpenAICompatibleLLM, MistralLLM}, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)

    return Dict(
        "type" => "image_url",
        "image_url" => Dict("url" => "data:$(mime_type);base64,$base64_encoded"),
    )
end

"""
    encode_file_to_base64(::GoogleLLM, file_path)

Returns a Google-specific JSON structure for inline data.
"""
function encode_file_to_base64(::GoogleLLM, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)

    return Dict(
        "inline_data" => Dict("mime_type" => "$(mime_type)", "data" => "$(base64_encoded)"),
    )
end

"""
    encode_file_to_base64(::AnthropicLLM, file_path)

Returns an Anthropic-specific JSON structure for base64-encoded attachments.
"""
function encode_file_to_base64(::AnthropicLLM, file_path)
    mime_type, base64_encoded = encode_file_to_base64(file_path)

    return Dict(
        "type" => "image",
        "source" => Dict("type" => "base64", "media_type" => "$(mime_type)", "data" => "$(base64_encoded)"),
    )
end

"""
    post_request(url, headers, payload)

Sends an HTTP POST request and handles potential errors, throwing exceptions on failure.

# Arguments
- `url`: The endpoint URL.
- `headers`: HTTP headers to include in the request.
- `payload`: The JSON-serializable data to send in the request body.

# Returns
An `HTTP.Response` if successful.

# Throws
- `ErrorException`: If the request fails with a non-200 status code.
- Any exceptions from the HTTP request itself.
"""
function post_request(url, headers, payload)
    try
        @debug "Payload" payload

        # Save payload for debugging (optional)
        temp = "/tmp/payload.jls"
        @debug "Saving payload to $temp"
        serialize(temp, payload)
        @debug "Payload saved"

        json_payload = JSON.json(payload)
        @debug "JSON payload ready"

        response = HTTP.request("POST", url, headers, json_payload; proxy=ENV["http_proxy"], status_exception=false) # Don't throw on status error initially

        if response.status >= 200 && response.status < 300
            return response
        else
            # Attempt to parse error details from the body
            api_error_message = ""
            try
                error_data = JSON.parse(String(response.body))
                # Common error structures (adjust as needed based on APIs)
                if haskey(error_data, "error") && haskey(error_data["error"], "message")
                    api_error_message = error_data["error"]["message"]
                elseif haskey(error_data, "message")
                    api_error_message = error_data["message"]
                elseif haskey(error_data, "detail")
                     api_error_message = error_data["detail"]
                else
                    api_error_message = String(response.body) # Fallback to raw body
                end
            catch parse_err
                @debug "Could not parse error response body as JSON" parse_err
                api_error_message = String(response.body) # Fallback to raw body
            end
            error_msg = "HTTP request failed with status $(response.status): $(api_error_message)"
            @error error_msg
            throw(ErrorException(error_msg))
        end
    catch http_error # Catch other HTTP errors (network, etc.)
        @error "HTTP request error occurred" exception=(http_error, catch_backtrace())
        throw(ErrorException("HTTP request failed: $(http_error)"))
    end
end

"""
    get_request(url, headers)

Sends an HTTP GET request to the specified URL and handles potential errors, 
returning the HTTP response or `nothing` on failure.

# Arguments
- `url`: The endpoint URL to send the GET request to. This should be a string 
  representing the full URL, including the protocol (e.g., `https://example.com`).
- `headers`: HTTP headers to include in the request.

# Returns
An `HTTP.Response` if the request is successful (status code 200); 
otherwise, `nothing` in case of an error or if the request fails with a non-200 status code.
"""
function get_request(url, header=Dict())
    try
        @debug "Sending GET request to $url"

        response = HTTP.request("GET", url, header; proxy=ENV["http_proxy"], status_exception=false) # Don't throw on status error initially

        if response.status >= 200 && response.status < 300
            return response
        else
             # Attempt to parse error details from the body
            api_error_message = ""
            try
                error_data = JSON.parse(String(response.body))
                 # Common error structures (adjust as needed based on APIs)
                if haskey(error_data, "error") && haskey(error_data["error"], "message")
                    api_error_message = error_data["error"]["message"]
                elseif haskey(error_data, "message")
                    api_error_message = error_data["message"]
                elseif haskey(error_data, "detail")
                     api_error_message = error_data["detail"]
                else
                    api_error_message = String(response.body) # Fallback to raw body
                end
            catch parse_err
                @debug "Could not parse error response body as JSON" parse_err
                api_error_message = String(response.body) # Fallback to raw body
            end
            error_msg = "HTTP GET request failed with status $(response.status): $(api_error_message)"
            @error error_msg
            throw(ErrorException(error_msg))
        end
    catch http_error # Catch other HTTP errors (network, etc.)
        @error "HTTP GET request error occurred" exception=(http_error, catch_backtrace())
        throw(ErrorException("HTTP GET request failed: $(http_error)"))
    end
end

"""
    handle_json_response(response, extraction_path)

Processes the JSON response and extracts the desired data from nested keys.

# Arguments
- `response::HTTP.Response`: The HTTP response object.
- `extraction_path::Vector{String}`: Array representing the path to the desired data.

# Returns
The extracted data if successful.

# Throws
- `ErrorException`: For JSON parsing or data extraction failures. HTTP status errors should be handled before calling this.
"""
function handle_json_response(response, extraction_path)
    # Status check removed - should be handled by post_request/get_request

    try
        response_data = JSON.parse(String(response.body))
        extracted_data = get_nested(response_data, extraction_path)
        return extracted_data
    catch error
        if error isa KeyError
            @error "Failed to extract data at path $extraction_path: $error"
            throw(ErrorException("Missing key in JSON response: $(error.key)"))
        else
            @error "Failed to parse JSON response: $error"
            throw(ErrorException("Invalid JSON response: $(String(response.body))"))
        end
    end
end

"""
    get_nested(data, path)

Navigates a nested dictionary to retrieve a value.

# Arguments
- `data`: The nested dictionary (or JSON-like structure).
- `path`: An array of keys representing the path to the desired value.

# Returns
The value located at the specified path, or throws a `KeyError` if missing.
"""
function get_nested(data, path)
    for key in path
        data = data[key]
    end
    return data
end

# ─────────────────────────────────────────────────────────────────────────────
# LLM Interaction Framework
# ─────────────────────────────────────────────────────────────────────────────

"""
    call_llm(llm::AbstractLLM; kwargs...)

Abstract method to call an LLM. Must be implemented for each concrete LLM type.

By default, this method raises an error indicating it is not implemented
for a given LLM subtype.
"""
function call_llm(llm::AbstractLLM; kwargs...)
    error("Not implemented for $(typeof(llm))")
end

"""
    make_api_request(llm, api_key, url, system_instruction, input_text, model, temperature, attach_file)

Prepares and sends an API request for OpenAI-compatible LLMs. Returns the text content
extracted from the LLM response or `nothing` if extraction fails.

# Arguments
- `llm::OpenAICompatibleLLM`: An instance of an OpenAI-compatible LLM type.
- `api_key`: API key for authentication.
- `url`: The API endpoint URL.
- `system_instruction`: The system-level instruction or context.
- `input_text`: The user-facing input text.
- `model`: The specific model to use.
- `temperature::Float64`: Sampling temperature for text generation.
- `attach_file`: Path to a file to attach (if any).

# Returns
A string containing the LLM response, or `nothing` if the request fails or no text is found.
"""
function make_api_request(
    llm::OpenAICompatibleLLM,
    api_key,
    url,
    system_instruction,
    input_text,
    model,
    temperature::Float64,
    attach_file
)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file

    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $api_key",
    ]

    text_data = Dict("type" => "text", "text" => input_text)
    content = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    @debug "API request content" content

    user_message   = Dict("role" => "user", "content" => content)
    system_message = Dict("role" => "system", "content" => system_instruction)

    messages = [user_message]
    if !isempty(system_instruction)
        @debug "Adding system message" system_message
        push!(messages, system_message)
    end

    data = Dict(
        "model" => model,
        "temperature" => temperature,
        "messages" => messages,
    )

    @debug "API request data" data

    response = post_request(url, headers, data)
    return handle_json_response(response, ["choices", 1, "message", "content"])
end

# ─────────────────────────────────────────────────────────────────────────────
# Specific LLM Implementations
# ─────────────────────────────────────────────────────────────────────────────

"""
    call_llm(llm::DeepSeekLLM, system_instruction, input_text, model, temperature, attach_file)

Calls the DeepSeek API with the provided parameters.

# Arguments
- `llm::DeepSeekLLM`: Instance of DeepSeekLLM
- `system_instruction`: System prompt/context
- `input_text`: User input text
- `model`: Model name from DeepSeek's offerings
- `temperature::Float64`: Sampling temperature
- `attach_file`: Optional file attachment path

# Returns
LLM response as String or nothing
"""
function call_llm(
    llm::DeepSeekLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("deepseek"),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file = "";
    kwargs...
)
    api_key = ENV["DEEPSEEK_API_KEY"]
    url     = "https://api.deepseek.com/v1/chat/completions"

    return make_api_request(
        llm,
        api_key,
        url,
        system_instruction,
        input_text,
        model,
        temperature,
        attach_file
    )
end

"""
    call_llm(llm::OpenAILLM,
             system_instruction,
             input_text,
             model,
             temperature::Float64,
             attach_file)

Calls the OpenAI API with the provided parameters.

# Arguments
- `llm::OpenAILLM`: Instance of OpenAILLM
- `system_instruction`: System-level instructions/context
- `input_text`: Main user text query/prompt
- `model`: Model name (default: ENV var or DEFAULT_MODELS)
- `temperature::Float64`: Sampling temperature
- `attach_file`: Path to file attachment

# Returns
LLM-generated response text as a `String`, or `nothing` if the request fails.
"""
function call_llm(
    llm::OpenAILLM,
    system_instruction="",
    input_text="",
    model = get_default_model("openai"),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file = "";
    kwargs...
)
    api_key = ENV["OPENAI_API_KEY"]
    url     = "https://api.openai.com/v1/chat/completions"

    return make_api_request(
        llm,
        api_key,
        url,
        system_instruction,
        input_text,
        model,
        temperature,
        attach_file
    )
end

"""
    call_llm(llm::OpenRouterLLM,
             system_instruction="",
             input_text="",
             model,
             temperature::Float64,
             attach_file)

Calls the OpenRouter API with the provided parameters.
"""
function call_llm(
    llm::OpenRouterLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("openrouter"),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file = "";
    kwargs...
)
    api_key = ENV["OPENROUTER_API_KEY"]
    url     = "https://openrouter.ai/api/v1/chat/completions"

    return make_api_request(
        llm,
        api_key,
        url,
        system_instruction,
        input_text,
        model,
        temperature,
        attach_file
    )
end

"""
    call_llm(llm::GroqLLM,
             system_instruction="",
             input_text="",
             model,
             temperature::Float64,
             attach_file)

Calls the Groq API with the provided parameters.

If a file is attached, Groq disallows mixing system instructions in the same message.
Therefore, the system_instruction is blanked out when attach_file is not empty
"""
function call_llm(
    llm::GroqLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("groq"),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file = "";
    kwargs...
)
    api_key = ENV["GROQ_API_KEY"]
    url     = "https://api.groq.com/openai/v1/chat/completions"

    # Groq does not allow system instructions + attachments in the same message
    sys_instruction = attach_file != "" ? "" : system_instruction

    return make_api_request(
        llm,
        api_key,
        url,
        sys_instruction,
        input_text,
        model,
        temperature,
        attach_file
    )
end

"""
    call_llm(llm::AnthropicLLM,
             system_instruction="",
             input_text="",
             model,
             temperature::Float64,
             attach_file)

Calls the Anthropic API (Claude) with the provided parameters.
"""
function call_llm(
    llm::AnthropicLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("anthropic"),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file = "";
    kwargs...
)
    thinking_budget = get(kwargs, :thinking_budget, 0) # Extract thinking budget
    @debug "Making API request" llm system_instruction input_text model temperature attach_file thinking_budget

    api_key = ENV["ANTHROPIC_API_KEY"]
    url     = "https://api.anthropic.com/v1/messages"

    headers = [
        "content-type"       => "application/json",
        "anthropic-version"  => "2023-06-01",
        "x-api-key"          => "$api_key",
    ]

    text_data = Dict("type" => "text", "text" => input_text)
    content   = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    data = Dict(
        "model"       => model,
        "max_tokens"  => 1024,
        "temperature" => temperature,
        "system"      => system_instruction,
        "messages"    => [ Dict("role" => "user", "content" => content) ],
    )

    # Add thinking config if applicable for claude-3-7-sonnet models
    if startswith(model, "claude-3-7-sonnet") && thinking_budget > 0
        @debug "Adding thinking budget to Anthropic request" thinking_budget
        data["thinking"] = Dict(
            "type" => "enabled",
            "budget_tokens" => thinking_budget
        )
        # Set max_tokens based on thinking_budget as per requirement
        calculated_max_tokens = ceil(Int, thinking_budget * 1.25)
        data["max_tokens"] = calculated_max_tokens
        @debug "Set max_tokens based on thinking budget" calculated_max_tokens

        # Set temperature to 1.0 when thinking is enabled
        data["temperature"] = 1.0
        @debug "Set temperature to 1.0 due to thinking budget"
    end

    response = post_request(url, headers, data)

    # Manually parse response to find the 'text' content, as 'thinking' might be the first element
    if response.status == 200
        try
            response_data = JSON.parse(String(response.body))
            content_array = get(response_data, "content", []) # Use get for safety

            # Find the first element with type "text"
            text_element_index = findfirst(item -> get(item, "type", "") == "text", content_array)

            if !isnothing(text_element_index)
                return get(content_array[text_element_index], "text", "") # Use get for safety
            else
                @error "No 'text' type found in Anthropic response content" response_data=response_data
                # Attempt to return the first element's text if available, as a fallback for non-thinking responses
                if !isempty(content_array) && haskey(content_array[1], "text")
                    @warn "Falling back to first content element's text"
                    return content_array[1]["text"]
                end
                throw(ErrorException("No text content found in Anthropic response"))
            end
        catch error
            @error "Failed to parse or process Anthropic JSON response" error=error body=String(response.body)
            throw(ErrorException("Invalid or unexpected JSON response format from Anthropic: $(String(response.body))"))
        end
    else
        # Reuse existing error handling logic from handle_json_response if status is not 200
        error_msg = "HTTP request failed with status $(response.status): $(String(response.body))"
        @error error_msg
        throw(ErrorException(error_msg))
    end
end

"""
    call_llm(llm::GoogleLLM,
             system_instruction="",
             input_text="",
             model,
             temperature::Float64,
             attach_file)

Calls the Google Generative Language API (PaLM, Gemini, etc.) with the provided parameters.
"""
function call_llm(
    llm::GoogleLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("google"),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file = "";
    kwargs...
)
    thinking_budget = get(kwargs, :thinking_budget, 0)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file thinking_budget

    api_key = ENV["GOOGLE_API_KEY"]
    url     = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key"

    headers = ["Content-Type" => "application/json"]

    text_data = Dict("text" => input_text)
    parts     = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    generation_config = Dict{String, Any}()
    generation_config["temperature"] = temperature

    # Only add thinkingConfig if the model is gemini-2.5 and budget > 0
    if startswith(model, "gemini-2.5") && thinking_budget > 0
        @debug "Adding thinking budget to generation config" thinking_budget
        generation_config["thinkingConfig"] = Dict("thinkingBudget" => thinking_budget)
    end

    data = Dict(
        "generationConfig"   => generation_config,
        "contents"           => Dict("parts" => parts),
    )

    if !isempty(system_instruction)
        @debug "Adding system instruction" system_instruction
        data["system_instruction"] = Dict("parts" => Dict("text" => system_instruction))
    end

    response = post_request(url, headers, data)
    return handle_json_response(response, ["candidates", 1, "content", "parts", 1, "text"])
end

"""
    call_llm(llm::OllamaLLM,
             system_instruction="",
             input_text="",
             model,
             temperature::Float64,
             attach_file)

Calls the Ollama API with the provided parameters (default local server endpoint).
"""
function call_llm(
    llm::OllamaLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("ollama"),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file = "";
    kwargs...
)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file

    url     = "http://127.0.0.1:11434/api/generate"
    headers = ["Content-Type" => "application/json"]

    data = Dict(
        "model"  => model,
        "prompt" => input_text,
        "stream" => false,
        "system" => system_instruction,
        "options" => Dict("temperature" => temperature),
    )

    response = post_request(url, headers, data)
    return handle_json_response(response, ["response"])
end

"""
    call_llm(llm::MistralLLM,
             system_instruction="",
             input_text="",
             model,
             temperature::Float64,
             attach_file)

Calls the Mistral API with the provided parameters.
"""
function call_llm(
    llm::MistralLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("mistral"),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file = "";
    kwargs...
)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file

    api_key = ENV["MISTRAL_API_KEY"]
    url     = "https://api.mistral.ai/v1/chat/completions"

    headers = [
        "Content-Type"  => "application/json",
        "Accept"        => "application/json",
        "Authorization" => "Bearer $api_key",
    ]

    text_data = Dict("type" => "text", "text" => input_text)
    content   = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    data = Dict(
        "model"       => model,
        "temperature" => temperature,
        "messages"    => [
            Dict("role" => "system", "content" => system_instruction),
            Dict("role" => "user",   "content" => content),
        ],
    )

    response = post_request(url, headers, data)
    return handle_json_response(response, ["choices", 1, "message", "content"])
end

# ─────────────────────────────────────────────────────────────────────────────
# Selecting LLM by Name
# ─────────────────────────────────────────────────────────────────────────────

"""
    get_llm_type(llm_name)

Retrieves the LLM type based on a string identifier (e.g. `"openai"`, `"anthropic"`).

# Arguments
- `llm_name`: The name of the LLM provider.

# Returns
An instance of the corresponding LLM type.

# Throws
`error` if `llm_name` is unknown.
"""
function get_llm_type(llm_name)
    llm_types = Dict(
        "openai"      => OpenAILLM(),
        "anthropic"   => AnthropicLLM(),
        "google"      => GoogleLLM(),
        "ollama"      => OllamaLLM(),
        "mistral"     => MistralLLM(),
        "openrouter"  => OpenRouterLLM(),
        "groq"        => GroqLLM(),
        "deepseek"    => DeepSeekLLM(),
    )
    get(llm_types, llm_name) do
        error("Unknown LLM: $llm_name")
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# call_llm Overloads
# ─────────────────────────────────────────────────────────────────────────────

"""
    call_llm(llm_name, system_instruction, input_text;
             model="", temperature=DEFAULT_TEMPERATURE)

Selects the appropriate LLM based on the provider name and invokes it.

# Arguments
- `llm_name`: Name of the LLM provider (e.g. "openai", "anthropic").
- `system_instruction`: System-level instructions or context.
- `input_text`: The user prompt or query.
- `model`: (Optional) A specific model to use. If empty, falls back to an environment
  variable or a default in `DEFAULT_MODELS`.
- `temperature::Float64`: (Optional) Sampling temperature.
- `copy::Bool`: (Optional) Whether to copy the response to the clipboard.

# Returns
The response from the selected LLM as `String` or `nothing` if the request fails.
"""
function call_llm(
    llm_name,
    system_instruction="",
    input_text="";
    model = "",
    temperature::Float64 = DEFAULT_TEMPERATURE,
    copy = false,
    thinking_budget::Int = 0 # Added thinking_budget
)
    llm_type = get_llm_type(llm_name)
    selected_model = resolve_model_alias(
        isempty(model) ? get_default_model(llm_name) : model
    )

    # Prepare kwargs for specific call_llm
    kwargs = Dict{Symbol, Any}()
    if thinking_budget > 0
        kwargs[:thinking_budget] = thinking_budget
    end

    result = call_llm(llm_type, system_instruction, input_text, selected_model, temperature; kwargs...)

    if !isempty(result) && copy
        clipboard(result)
    end

    return result
end

"""
    call_llm(system_instruction, args)

A general-purpose function that calls the appropriate LLM using a configuration
dictionary of arguments. This wraps the logic of extracting `input_text`, `model`,
`temperature`, and `attachment` from `args`.

# Arguments
- `system_instruction`: System-level instructions or context.
- `args::Dict`: A dictionary containing (at least) the following keys:
    - `"llm"` (`String`): The LLM provider name, e.g. `"openai"`.
    - `"input_text"` (`String`): The user prompt or query text.
    - `"model"` (`String`): The model name to use.
    - `"temperature"` (`Float64`): The sampling temperature.
    - `"attachment"` (`String`): Path to a file to attach (optional).

# Returns
The LLM response as a `String`, or `nothing` if the request fails.
"""
function call_llm(system_instruction, args::Dict)
    llm_type    = get_llm_type(args["llm"])
    input_text      = args["input_text"]
    model           = resolve_model_alias(args["model"])
    temperature     = args["temperature"]
    attach_file     = haskey(args, "attachment") ? args["attachment"] : ""
    copy            = args["copy"]
    thinking_budget = args["thinking_budget"] # Extract thinking_budget

    # Prepare kwargs for specific call_llm
    kwargs = Dict{Symbol, Any}()
    if thinking_budget > 0
        kwargs[:thinking_budget] = thinking_budget
    end

    result = call_llm(
        llm_type,
        system_instruction,
        input_text,
        model,
        temperature,
        attach_file;
        kwargs... # Pass kwargs
    )

    if !isempty(result) && copy
        clipboard(result)
    end

    return result
end

#-----------------------------------------------------------------------------------
# List LLM Models
#-----------------------------------------------------------------------------------------------

"""
    list_llm_models(llm::GoogleLLM)

Lists the available models from Google's Generative Language API.

# Arguments
- `llm::GoogleLLM`: Instance of `GoogleLLM`.
- `api_key`: API key for authentication.

# Returns
A list of models.
"""
function list_llm_models(llm::GoogleLLM)
    @debug "Listing LLM Models" llm

    api_key = ENV["GOOGLE_API_KEY"]
    url = "https://generativelanguage.googleapis.com/v1beta/models?key=$api_key"

    response = get_request(url)
    model_list = handle_json_response(response, ["models"])

    # Extract the "name" field into a vector of strings
    model_names = [replace(model["name"], "models/" => "") for model in model_list]

    return model_names
end

"""
    list_llm_models(llm::AnthropicLLM)

Lists the available models from Anthropic's Generative Language API.

# Arguments
- `llm::AnthropicLLM`: Instance of `AnthropicLLM`.
- `api_key`: API key for authentication.

# Returns
A list of models.
"""
function list_llm_models(llm::AnthropicLLM)
    @debug "Listing LLM Models" llm

    api_key = ENV["ANTHROPIC_API_KEY"]
    headers = [
        "content-type"       => "application/json",
        "anthropic-version"  => "2023-06-01",
        "x-api-key"          => "$api_key",
    ]

    url     = "https://api.anthropic.com/v1/models"

    response = get_request(url, headers)
    model_list = handle_json_response(response, ["data"])

    # Extract the "name" field into a vector of strings
    model_names = [model["id"] for model in model_list]

    return model_names
end

"""
    list_llm_models(llm::OpenRouterLLM)

Lists the available models from OpenRouter's Generative Language API.

# Arguments
- `llm::OpenRouterLLM`: Instance of `OpenRouterLLM`.
- `api_key`: API key for authentication.

# Returns
A list of models.
"""
function list_llm_models(llm::OpenRouterLLM)
    @debug "Listing LLM Models" llm

    url     = "https://openrouter.ai/api/v1/models"

    response = get_request(url)
    model_list = handle_json_response(response, ["data"])

    # Extract the "name" field into a vector of strings
    model_names = [model["id"] for model in model_list]

    return model_names
end

"""
    list_llm_models(llm::GroqLLM)

Lists the available models from Groq's Generative Language API.

# Arguments
- `llm::GroqLLM`: Instance of `GroqLLM`.
- `api_key`: API key for authentication.

# Returns
A list of models.
"""
function list_llm_models(llm::GroqLLM)
    @debug "Listing LLM Models" llm

    api_key = ENV["GROQ_API_KEY"]
    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $api_key",
    ]

    url     = "https://api.groq.com/openai/v1/models"

    response = get_request(url, headers)
    model_list = handle_json_response(response, ["data"])

    # Extract the "name" field into a vector of strings
    model_names = [model["id"] for model in model_list]

    return model_names
end

"""
    list_llm_models(llm::OpenAILLM)

Lists the available models from OpenAI's Generative Language API.

# Arguments
- `llm::OpenAILLM`: Instance of `OpenAILLM`.
- `api_key`: API key for authentication.

# Returns
A list of models.
"""
function list_llm_models(llm::OpenAILLM)
    @debug "Listing LLM Models" llm

    api_key = ENV["OPENAI_API_KEY"]
    headers = [
        "Authorization" => "Bearer $api_key",
    ]

    url     = "https://api.openai.com/v1/models"

    response = get_request(url, headers)
    model_list = handle_json_response(response, ["data"])

    # Extract the "name" field into a vector of strings
    model_names = [model["id"] for model in model_list]

    return model_names
end

"""
    list_llm_models(llm::MistralLLM)

Lists the available models from Mistral's Generative Language API.

# Arguments
- `llm::MistralLLM`: Instance of `MistralLLM`.
- `api_key`: API key for authentication.

# Returns
A list of models.
"""
function list_llm_models(llm::MistralLLM)
    @debug "Listing LLM Models" llm

    api_key = ENV["MISTRAL_API_KEY"]
    headers = [
        "Authorization" => "Bearer $api_key",
    ]

    url     = "https://api.mistral.ai/v1/models"

    response = get_request(url, headers)
    model_list = handle_json_response(response, ["data"])

    # Extract the "name" field into a vector of strings
    model_names = [model["id"] for model in model_list]

    return model_names
end

"""
    list_llm_models(llm::DeepSeekLLM)

Lists available models from DeepSeek's API.

# Arguments
- `llm::DeepSeekLLM`: Instance of DeepSeekLLM

# Returns
Vector of available model names
"""
function list_llm_models(llm::DeepSeekLLM)
    @debug "Listing LLM Models" llm

    api_key = ENV["DEEPSEEK_API_KEY"]
    headers = [
        "Authorization" => "Bearer $api_key",
    ]

    url     = "https://api.deepseek.com/v1/models"

    response = get_request(url, headers)
    model_list = handle_json_response(response, ["data"])

    # Extract the "name" field into a vector of strings
    model_names = [model["id"] for model in model_list]

    return model_names
end

"""
    list_llm_models(llm::OllamaLLM)

Lists the available models from Ollama's Generative Language API.

# Arguments
- `llm::OllamaLLM`: Instance of OllamaLLM

# Returns
A list of models.
"""
function list_llm_models(llm::OllamaLLM)
    @debug "Listing LLM Models" llm

    url     = "http://127.0.0.1:11434/api/tags"

    response = get_request(url)
    model_list = handle_json_response(response, ["models"])

    # Extract the "name" field into a vector of strings
    model_names = [model["model"] for model in model_list]

    return model_names
end

# ─────────────────────────────────────────────────────────────────────────────
# Command-line Parsing
# ─────────────────────────────────────────────────────────────────────────────

"""
    create_default_settings()

Creates an `ArgParseSettings` object with a basic description and version.
"""
function create_default_settings()
    return ArgParseSettings(
        description = "Process text using various LLM providers.",
        add_version = true,
    )
end

"""
    parse_commandline(settings; require_input=true)

Parses command-line arguments for the LLM script, determining the default LLM and model
if none are specified by the user.

# Arguments
- `settings`: The argument parsing settings.
- `require_input`: Whether input text is required (default: `true`).

# Returns
A dictionary containing parsed command-line arguments:
- `"llm"`: The LLM provider (e.g., `"openai"`).
- `"model"`: The model to use.
- `"file"`: Path to the file to process (if any).
- `"attachment"`: Path to a file to attach (if any).
- `"temperature"`: Sampling temperature.
- `"debug"`: Whether debug mode is enabled.
- `"input_text"`: The user-supplied text
"""
function parse_commandline(
    settings = create_default_settings();
    require_input::Bool = true
)
    llm   = get_default_llm()
    model = get_default_model(llm)
    return parse_commandline(settings, llm, model; require_input=require_input)
end

"""
    parse_commandline(settings, default_llm; require_input=true)

Same as `parse_commandline(settings)` but uses an explicit default LLM name.
"""
function parse_commandline(
    settings,
    default_llm::String;
    require_input = true
)
    default_model = get_default_model(default_llm)
    return parse_commandline(settings, default_llm, default_model; require_input=require_input)
end

"""
    parse_commandline(settings, default_llm, default_model; require_input=true)

Parses command-line arguments for the LLM script when both the default LLM provider and model
are specified.

The returned dictionary includes:
- `"llm"`: LLM provider (string)
- `"model"`: Model name (string).
- `"file"`: Path to the file to process (if any).
- `"attachment"`: File to attach (if any).
- `"temperature"`: Sampling temperature (float).
- `"debug"`: Boolean flag for debug mode.
- `"input_text"`: Input text or prompt (string)

If `require_input` is `true` and the user does not provide `input_text`, reads from `stdin`.
"""
function parse_commandline(
    settings,
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
        help = "Path to input file to process"
        default = ""

        "--attachment", "-a" 
        help = "Path to file attachment"
        default = ""

        "--temperature", "-t"
        help = "Sampling temperature (0.0-2.0)"
        arg_type = Float64
        default = 0.7  # Uses DEFAULT_TEMPERATURE if not set

        "--debug", "-d"
        help = "Enable debug logging"
        action = :store_true

        "--copy", "-c"
        help = "Copy response to clipboard"
        action = :store_true

        "--thinking_budget", "-B"
        help = "Thinking budget for compatible models (e.g., Gemini)"
        arg_type = Int
        default = 0

        "input_text"
        help = "Input text/prompt (reads from stdin if empty)"
        required = false
    end

    args = parse_args(settings)

    # If no input_text was provided and we require it, read from stdin
    if isnothing(args["input_text"]) && require_input
        args["input_text"] = chomp(read(stdin, String))
    end

    # If the user changed the LLM but not the model, use that LLM's default model
    if args["llm"] != default_llm && args["model"] == default_model
        args["model"] = get_default_model(args["llm"])
    end

    # Enable debug logging if requested
    if args["debug"]
        global_logger(ConsoleLogger(stderr, Logging.Debug))
        @info "Debug mode enabled"
    end

    return args
end

#-----------------------------------------------------------------------------------------------
# Jina
# ---------------------------------------------------------------------------------------------
"""
    jina_reader(url)

Convert web page to markdown with a Jina reader.

# Arguments
- `url`: URL of the web page to convert.

# Returns
A string containing the converted markdown.
"""
function jina_reader(url)
    request_url = "https://r.jina.ai/$url"
    api_key = ENV["JINA_API_KEY"]
    headers = ["Authorization" => "Bearer $api_key"]
    response = HTTP.request("GET", request_url, headers, proxy = ENV["http_proxy"])
    return String(response.body)
end

#-----------------------------------------------------------------------------------------------
# Pandoc
# ---------------------------------------------------------------------------------------------
"""
   pandoc_reader(url)

Fetches the content from a given URL,
converts it from HTML to Markdown using pandoc.

# Arguments
- `url`: The URL from which to fetch the content.

# Returns
A string containing the converted markdown.
"""
function pandoc_reader(url::String)
    # Fetch the content from the URL
    response = HTTP.get(url)
    content = String(response.body)

    # Convert the fetched content to markdown using Pandoc
    c = Pandoc.Converter(input = content)
    c.from = "html"  # assuming the content from URL is HTML
    c.to = "markdown"  # converting to markdown

    # Run the conversion
    return String(run(c))
end
end # module LLMAccess
