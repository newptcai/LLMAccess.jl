function call_llm(
    llm::OllamaLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("ollama"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    think = get(kwargs, :think, 0)
    dry_run = get(kwargs, :dry_run, false)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file think

    url     = "http://127.0.0.1:11434/api/generate"
    headers = ["Content-Type" => "application/json"]

    data = Dict{String, Any}(
        "model"  => model,
        "prompt" => input_text,
        "stream" => false,
        "options" => Dict("temperature" => temperature),
    )

    if !isempty(system_instruction)
        data["system"] = system_instruction
    end

    data["think"] = think != 0

    if attach_file != ""
        @debug "Attaching file to Ollama request" attach_file
        _ , base64_encoded = encode_file_to_base64(attach_file)
        data["images"] = [base64_encoded]
    end

    if dry_run
        return JSON.json(data)
    end

    response = post_request(url, headers, data)
    return handle_json_response(response, ["response"])
end

