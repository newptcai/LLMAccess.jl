module LLMAccess

using HTTP
using JSON

export call_llm

# Default models for each LLM provider
DEFAULT_MODELS = Dict(
    "openai" => "gpt-4o-mini",
    "anthropic" => "claude-3-haiku-20240307",
    "google" => "gemini-1.5-flash",
    "ollama" => "llama3.2",
    "mistral" => "mistral-small-latest"
)

# Default temperature
DEFAULT_TEMPERATURE = 0.4

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

# Function to call OpenAI API
function call_openai(input_text::String, 
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
function call_anthropic(input_text::String,
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
function call_google(input_text::String, 
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
function call_ollama(input_text::String,
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
function call_mistral(input_text::String,
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

# Function to select LLM and call corresponding model
function call_llm(llm::String,
        input_text::String,
        system_instruction::String,
        model::String="",
        temperature::Float64=DEFAULT_TEMPERATURE)
    if model == ""
        model = DEFAULT_MODELS[llm]
    end
    
    if llm == "openai"
        return call_openai(input_text, system_instruction, model, temperature)
    elseif llm == "anthropic"
        return call_anthropic(input_text, system_instruction, model, temperature)
    elseif llm == "google"
        return call_google(input_text, system_instruction, model, temperature)
    elseif llm == "ollama"
        return call_ollama(input_text, system_instruction, model, temperature)
    elseif llm == "mistral"
        return call_mistral(input_text, system_instruction, model, temperature)
    else
        error("Unknown LLM selected!")
    end
end

end # module LLMAccess
