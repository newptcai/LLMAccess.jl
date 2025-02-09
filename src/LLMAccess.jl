module LLMAccess

using HTTP
using JSON
using ArgParse
using Base64
using MIMEs
using Logging
using Serialization

export call_llm, list_llm_models, get_llm_type, parse_commandline

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

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

const DEFAULT_MODELS = Dict(
    "openai"      => "gpt-4o-mini",
    "openrouter"  => "amazon/nova-micro-v1",
    "anthropic"   => "claude-3-5-haiku-latest",
    "google"      => "gemini-2.0-flash",
    "ollama"      => "llama3.2",
    "mistral"     => "mistral-small-latest",
    "groq"        => "llama-3.3-70b-versatile",
)

const DEFAULT_TEMPERATURE = 0.7
const DEFAULT_LLM = "google"

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
    get_default_model(llm_name)

Returns the default model for the given provider, determined by the environment
variable `DEFAULT_<LLM_NAME>_MODEL` (converted to uppercase) or a hard-coded fallback
in `DEFAULT_MODELS`.
"""
function get_default_model(llm_name)
    return get(ENV, "DEFAULT_"*uppercase(llm_name)*"_MODEL", DEFAULT_MODELS[llm_name])
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

Sends an HTTP POST request and handles potential errors, returning the HTTP response
or `nothing` on failure.

# Arguments
- `url`: The endpoint URL.
- `headers`: HTTP headers to include in the request.
- `payload`: The JSON-serializable data to send in the request body.

# Returns
An `HTTP.Response` if successful; otherwise, `nothing`.
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

        response = HTTP.request("GET", url, header, proxy=ENV["http_proxy"])

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

Processes the JSON response and extracts the desired data from nested keys.

# Arguments
- `response::HTTP.Response`: The HTTP response object.
- `extraction_path::Vector{String}`: An array representing the path to the desired data in the JSON structure.

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

    messages = system_instruction == "" ? [user_message] : [system_message, user_message]

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
    call_llm(llm::OpenAILLM,
             system_instruction,
             input_text,
             model,
             temperature::Float64,
             attach_file)

Calls the OpenAI API with the provided parameters.

# Arguments
- `llm::OpenAILLM`: Instance of `OpenAILLM`.
- `system_instruction`: System-level instructions or context.
- `input_text`: The main user text query/prompt.
- `model`: Model name (defaults to the ENV var `OPENAI_DEFAULT_MODEL` or the fallback in `DEFAULT_MODELS`).
- `temperature::Float64`: Sampling temperature.
- `attach_file`: Path to a file to attach.

# Returns
LLM-generated response text as a `String`, or `nothing` if the request fails.
"""
function call_llm(
    llm::OpenAILLM,
    system_instruction="",
    input_text="",
    model = get_default_model("openai"),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file = ""
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
    attach_file = ""
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
Therefore, the `system_instruction` is blanked out when `attach_file` is not empty.
"""
function call_llm(
    llm::GroqLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("groq"),
    temperature::Float64 = DEFAULT_TEMPERATURE,
    attach_file = ""
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
    attach_file = ""
)
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

    response = post_request(url, headers, data)
    return handle_json_response(response, ["content", 1, "text"])
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
    attach_file = ""
)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file

    api_key = ENV["GOOGLE_API_KEY"]
    url     = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key"

    headers = ["Content-Type" => "application/json"]

    text_data = Dict("text" => input_text)
    parts     = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    data = Dict(
        "system_instruction" => Dict("parts" => Dict("text" => system_instruction)),
        "generationConfig"   => Dict("temperature" => temperature),
        "contents"           => Dict("parts" => parts),
    )

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
    attach_file = ""
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
    attach_file = ""
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

# Returns
The response from the selected LLM as `String` or `nothing` if the request fails.
"""
function call_llm(
    llm_name,
    system_instruction="",
    input_text="";
    model = "",
    temperature::Float64 = DEFAULT_TEMPERATURE
)
    llm_type = get_llm_type(llm_name)
    selected_model = isempty(model) ? get_default_model(llm_name) : model

    result = call_llm(llm_type, system_instruction, input_text, selected_model, temperature)
    println(result)
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
    input_text  = args["input_text"]
    model       = args["model"]
    temperature = args["temperature"]
    attach_file = haskey(args, "attachment") ? args["attachment"] : ""

    return call_llm(
        llm_type,
        system_instruction,
        input_text,
        model,
        temperature,
        attach_file
    )
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
    list_llm_models(llm::OllamaLLM)

Lists the available models from Ollama's Generative Language API.

# Arguments
- `llm::OllamaLLM`: Instance of `OllamaLLM`.
- `api_key`: API key for authentication.

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
- `"input_text"`: The user-supplied text.
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
- `"llm"`: LLM provider (string).
- `"model"`: Model name (string).
- `"file"`: Path to the file to process (if any).
- `"attachment"`: File to attach (if any).
- `"temperature"`: Sampling temperature (float).
- `"debug"`: Boolean flag for debug mode.
- `"input_text"`: Input text or prompt (string).

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
        help = "Path to the file to process"
        default = ""

        "--attachment", "-a"
        help = "Path to the file to attach"
        default = ""

        "--temperature", "-t"
        help = "Temperature for text generation"
        arg_type = Float64
        default = 0.7  # fallback to your DEFAULT_TEMPERATURE if desired

        "--debug", "-d"
        help = "Enable debug mode"
        action = :store_true

        "input_text"
        help = "Input text for the LLM (reads from stdin if not provided)"
        required = false
    end

    args = parse_args(settings)

    # If no input_text was provided and we require it, read from stdin
    if isnothing(args["input_text"]) && require_input
        args["input_text"] = read(stdin, String)
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

end # module LLMAccess
