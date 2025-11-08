"""
    get_llm_type(llm_name)

Map provider name to concrete LLM type instance.
"""
function get_llm_type(llm_name)
    canonical = resolve_provider_alias(llm_name)
    llm_types = Dict(
        "openai"      => OpenAILLM(),
        "anthropic"   => AnthropicLLM(),
        "minimax"     => MinimaxLLM(),
        "google"      => GoogleLLM(),
        "ollama"      => OllamaLLM(),
        "ollama_cloud" => OllamaCloudLLM(),
        "mistral"     => MistralLLM(),
        "openrouter"  => OpenRouterLLM(),
        "groq"        => GroqLLM(),
        "deepseek"    => DeepSeekLLM(),
        "zai"         => ZaiLLM(),
        "cerebras"    => CerebrasLLM(),
    )
    get(llm_types, canonical) do
        error("Unknown LLM: $llm_name")
    end
end

"""
    call_llm(llm_name, system_instruction, input_text; model="", temperature=get_default_temperature(), copy=false, think::Int=0, dry_run::Bool=false)

Dispatch to a provider by name (string), handling defaults and model aliasing.
"""
function call_llm(
    llm_name,
    system_instruction="",
    input_text="";
    model = "",
    temperature::Float64 = get_default_temperature(),
    copy = false,
    think::Int = 0,
    dry_run::Bool = false,
    normalize_output::Bool = true
)
    canonical_llm = resolve_provider_alias(llm_name)
    llm_type = get_llm_type(canonical_llm)
    default_model_for_llm = get_default_model(canonical_llm)
    model_to_resolve = isempty(model) ? default_model_for_llm : model
    selected_model = resolve_model_alias(model_to_resolve)

    kwargs = Dict{Symbol, Any}()
    if think != 0
        kwargs[:think] = think
    end
    if dry_run
        kwargs[:dry_run] = true
    end

    result = call_llm(llm_type, system_instruction, input_text, selected_model, temperature; kwargs...)
    # Normalize punctuation unless explicit opt-out
    if normalize_output
        result = normalize_output_text(result)
    end
    if !isempty(result) && copy
        clipboard(result)
    end
    return result
end

"""
    call_llm(system_instruction, args::Dict)

Call the appropriate provider based on config dictionary.
"""
function call_llm(system_instruction, args::Dict)
    canonical_llm = resolve_provider_alias(args["llm"]) 
    llm_type    = get_llm_type(canonical_llm)
    input_text  = args["input_text"]
    model       = resolve_model_alias(args["model"])
    temperature = args["temperature"]
    attach_file = haskey(args, "attachment") ? args["attachment"] : ""
    copy        = args["copy"]
    think       = args["think"]
    dry_run     = get(args, "dry_run", false)

    kwargs = Dict{Symbol, Any}()
    if think != 0
        kwargs[:think] = think
    end
    if dry_run
        kwargs[:dry_run] = true
    end

    result = call_llm(llm_type, system_instruction, input_text, model, temperature, attach_file; kwargs...)
    # Normalize punctuation unless explicit opt-out via CLI flag
    do_normalize = !get(args, "no_normalize", false)
    if do_normalize
        result = normalize_output_text(result)
    end
    if !isempty(result) && copy
        clipboard(result)
    end
    return result
end
