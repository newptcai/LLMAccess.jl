function call_llm(
    llm::GoogleLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("google"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    think = get(kwargs, :think, 0)
    dry_run = get(kwargs, :dry_run, false)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file think

    api_key = ENV["GOOGLE_API_KEY"]
    url     = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$api_key"
    headers = ["Content-Type" => "application/json"]

    text_data = Dict("text" => input_text)
    parts = attach_file != "" ? [text_data, encode_file_to_base64(llm, attach_file)] : [text_data]

    generation_config = Dict{String, Any}()
    generation_config["temperature"] = temperature
    if think != 0
        @debug "Adding thinking budget to generation config" think
        generation_config["thinkingConfig"] = Dict("thinkingBudget" => think)
    end

    data = Dict(
        "generationConfig" => generation_config,
        "contents" => [Dict("role" => "user", "parts" => parts)],
    )
    if !isempty(system_instruction)
        data["system_instruction"] = Dict("role" => "system", "parts" => [Dict("text" => system_instruction)])
    end

    if dry_run
        return JSON.json(data)
    end

    response = post_request(url, headers, data)
    return extract_google_text(response)
end

