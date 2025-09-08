"""
    list_llm_models(llm::GoogleLLM)

List available models from Google's Generative Language API.
"""
function list_llm_models(llm::GoogleLLM)
    @debug "Listing LLM Models" llm
    api_key = ENV["GOOGLE_API_KEY"]
    url = "https://generativelanguage.googleapis.com/v1beta/models?key=$api_key"
    response = get_request(url)
    model_list = handle_json_response(response, ["models"])
    return [replace(model["name"], "models/" => "") for model in model_list]
end

"""
    list_llm_models(llm::AnthropicLLM)

List available models from Anthropic.
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
    return [model["id"] for model in model_list]
end

"""
    list_llm_models(llm::OpenRouterLLM)

List available models from OpenRouter.
"""
function list_llm_models(llm::OpenRouterLLM)
    @debug "Listing LLM Models" llm
    url = "https://openrouter.ai/api/v1/models"
    response = get_request(url)
    model_list = handle_json_response(response, ["data"])
    return [model["id"] for model in model_list]
end

"""
    list_llm_models(llm::GroqLLM)

List available models from Groq.
"""
function list_llm_models(llm::GroqLLM)
    @debug "Listing LLM Models" llm
    api_key = ENV["GROQ_API_KEY"]
    headers = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $api_key",
    ]
    url = "https://api.groq.com/openai/v1/models"
    response = get_request(url, headers)
    model_list = handle_json_response(response, ["data"])
    return [model["id"] for model in model_list]
end

"""
    list_llm_models(llm::OpenAILLM)

List available models from OpenAI.
"""
function list_llm_models(llm::OpenAILLM)
    @debug "Listing LLM Models" llm
    api_key = ENV["OPENAI_API_KEY"]
    headers = ["Authorization" => "Bearer $api_key"]
    url     = "https://api.openai.com/v1/models"
    response = get_request(url, headers)
    model_list = handle_json_response(response, ["data"])
    return [model["id"] for model in model_list]
end

"""
    list_llm_models(llm::MistralLLM)

List available models from Mistral.
"""
function list_llm_models(llm::MistralLLM)
    @debug "Listing LLM Models" llm
    api_key = ENV["MISTRAL_API_KEY"]
    headers = ["Authorization" => "Bearer $api_key"]
    url     = "https://api.mistral.ai/v1/models"
    response = get_request(url, headers)
    model_list = handle_json_response(response, ["data"])
    return [model["id"] for model in model_list]
end

"""
    list_llm_models(llm::DeepSeekLLM)

List available models from DeepSeek.
"""
function list_llm_models(llm::DeepSeekLLM)
    @debug "Listing LLM Models" llm
    api_key = ENV["DEEPSEEK_API_KEY"]
    headers = ["Authorization" => "Bearer $api_key"]
    url     = "https://api.deepseek.com/v1/models"
    response = get_request(url, headers)
    model_list = handle_json_response(response, ["data"])
    return [model["id"] for model in model_list]
end

"""
    list_llm_models(llm::OllamaLLM)

List available models from local Ollama.
"""
function list_llm_models(llm::OllamaLLM)
    @debug "Listing LLM Models" llm
    url     = "http://127.0.0.1:11434/api/tags"
    response = get_request(url)
    model_list = handle_json_response(response, ["models"])
    return [model["model"] for model in model_list]
end

"""
    list_llm_models(llm::ZaiLLM)

Return supported model names for Z.ai provider.
"""
function list_llm_models(llm::ZaiLLM)
    # Z.ai API model listing isn’t standardized publicly; hardcode known ones
    return [
        "glm-4.5",
        "glm-4.5-air",
    ]
end
