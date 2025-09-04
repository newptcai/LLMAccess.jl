function call_llm(
    llm::MistralLLM,
    system_instruction="",
    input_text="",
    model = get_default_model("mistral"),
    temperature::Float64 = get_default_temperature(),
    attach_file = "";
    kwargs...
)
    @debug "Making API request" llm system_instruction input_text model temperature attach_file
    dry_run = get(kwargs, :dry_run, false)

    api_key = ENV["MISTRAL_API_KEY"]
    headers = [
        "Content-Type"  => "application/json",
        "Accept"        => "application/json",
        "Authorization" => "Bearer $api_key",
    ]

    # Special handling for OCR models that use a different endpoint and payload shape.
    if startswith(lowercase(model), "mistral-ocr")
        if isempty(attach_file)
            error("mistral-ocr models require an attachment. Provide --attachment <image path>.")
        end

        # Build OCR payload per Mistral API (document.image_url is a data: URL string).
        mime_type, b64 = encode_file_to_base64(attach_file)
        url = "https://api.mistral.ai/v1/ocr"
        data = Dict(
            "model" => model,
            "document" => Dict(
                "type" => "image_url",
                "image_url" => "data:$(mime_type);base64,$b64",
            ),
            # Provide image bytes in response to simplify offline inspection.
            "include_image_base64" => true,
        )

        if dry_run
            return JSON.json(data)
        end

        response = post_request(url, headers, data)
        # Try to extract text robustly; fallback to raw JSON if unknown.
        try
            payload = JSON.parse(String(response.body))
            if haskey(payload, "text") && !isempty(String(payload["text"]))
                return String(payload["text"])  # common field name
            end
            if haskey(payload, "ocr_text") && !isempty(String(payload["ocr_text"]))
                return String(payload["ocr_text"])  # alternate field name
            end
            if haskey(payload, "result") && !isempty(String(payload["result"]))
                return String(payload["result"])  # generic field name
            end
            if haskey(payload, "markdown") && !isempty(String(payload["markdown"]))
                return String(payload["markdown"])  # top-level markdown if provided
            end
            if haskey(payload, "pages") && payload["pages"] isa AbstractVector
                # Concatenate page-level text if present
                page_texts = String[]
                for page in payload["pages"]
                    if page isa AbstractDict
                        if haskey(page, "markdown") && !isempty(String(page["markdown"]))
                            push!(page_texts, String(page["markdown"]))
                            continue
                        end
                        if haskey(page, "text")
                            push!(page_texts, String(page["text"]))
                        elseif haskey(page, "ocr_text")
                            push!(page_texts, String(page["ocr_text"]))
                        end
                    end
                end
                if !isempty(page_texts)
                    return join(page_texts, "\n\n")
                end
            end
            # Unknown structure: return compact JSON for visibility
            return JSON.json(payload)
        catch
            # As a last resort, return raw body
            return String(response.body)
        end
    end

    # Default chat/completions path (supports multimodal via OpenAI-compatible payload)
    url     = "https://api.mistral.ai/v1/chat/completions"

    user_content = if isempty(attach_file)
        input_text
    else
        text_data = Dict("type" => "text", "text" => input_text)
        [text_data, encode_file_to_base64(llm, attach_file)]
    end

    messages = []
    if !isempty(system_instruction)
        push!(messages, Dict("role" => "system", "content" => system_instruction))
    end
    push!(messages, Dict("role" => "user", "content" => user_content))

    data = Dict(
        "model"       => model,
        "temperature" => temperature,
        "messages"    => messages,
    )

    if dry_run
        return JSON.json(data)
    end

    response = post_request(url, headers, data)
    return handle_json_response(response, ["choices", 1, "message", "content"])
end
