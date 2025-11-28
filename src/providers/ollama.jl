const OLLAMA_LOCAL_URL = "http://127.0.0.1:11434/api/generate"
const OLLAMA_CLOUD_URL = "https://ollama.com/api/chat"

function call_llm(
    llm::OllamaLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("ollama"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    headers = ["Content-Type" => "application/json"]
    return _call_ollama_backend(
        :local,
        headers,
        system_instruction,
        input_text,
        model,
        temperature,
        attach_file;
        kwargs...
    )
end

function call_llm(
    llm::OllamaCloudLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("ollama_cloud"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    api_key = ENV["OLLAMA_API_KEY"]
    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $api_key",
    ]
    return _call_ollama_backend(
        :cloud,
        headers,
        system_instruction,
        input_text,
        model,
        temperature,
        attach_file;
        kwargs...
    )
end

function _call_ollama_backend(
    mode::Symbol,
    headers,
    system_instruction,
    input_text,
    model,
    temperature,
    attach_file;
    kwargs...
)
    think_level = get(kwargs, :think, ThinkNone)
    dry_run = get(kwargs, :dry_run, false)
    schema_content = get(kwargs, :schema_content, "")
    provider_label = mode == :cloud ? "Ollama Cloud" : "Ollama"
    @debug "Making $(provider_label) request" system_instruction input_text model temperature attach_file think_level schema_content

    payload = _build_ollama_payload(
        mode,
        system_instruction,
        input_text,
        model,
        temperature,
        attach_file,
        think_level,
        schema_content,
    )

    if dry_run
        return JSON.json(payload)
    end

    url = mode == :cloud ? OLLAMA_CLOUD_URL : OLLAMA_LOCAL_URL
    response = post_request(url, headers, payload)
    path = mode == :cloud ? ["message", "content"] : ["response"]
    return handle_json_response(response, path)
end

function _build_ollama_payload(
    mode::Symbol,
    system_instruction,
    input_text,
    model,
    temperature,
    attach_file,
    think_level::ThinkLevel,
    schema_content,
)
    data = Dict{String, Any}()
    data["model"] = model
    data["stream"] = false
    data["think"] = think_level != ThinkNone
    data["options"] = Dict("temperature" => temperature)

    if !isempty(schema_content)
        if schema_content == "json"
            data["format"] = "json"
        else
            try
                data["format"] = JSON.parse(schema_content)
            catch
                data["format"] = schema_content
            end
        end
    end

    maybe_image = _maybe_encode_ollama_image(attach_file)

    if mode == :cloud
        messages = Vector{Dict{String, Any}}()
        if !isempty(system_instruction)
            push!(messages, Dict("role" => "system", "content" => system_instruction))
        end
        user_message = Dict("role" => "user", "content" => input_text)
        if maybe_image !== nothing
            user_message["images"] = [maybe_image]
        end
        push!(messages, user_message)
        data["messages"] = messages
    else
        data["prompt"] = input_text
        if !isempty(system_instruction)
            data["system"] = system_instruction
        end
        if maybe_image !== nothing
            data["images"] = [maybe_image]
        end
    end

    return data
end

function _maybe_encode_ollama_image(attach_file)
    if isempty(attach_file)
        return nothing
    end
    @debug "Attaching file to Ollama request" attach_file
    _, base64_encoded = encode_file_to_base64(attach_file)
    return base64_encoded
end
