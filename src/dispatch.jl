"""
    LLMDispatchConfig

Normalize dispatch options once so providers receive consistent, typed kwargs.
"""
struct LLMDispatchConfig
    think::ThinkLevel
    dry_run::Bool
    schema_content::String
    normalize_output::Bool
    copy_output::Bool
end

function LLMDispatchConfig(; think::Integer = 0, dry_run::Bool = false,
                            schema_content::AbstractString = "",
                            normalize_output::Bool = true,
                            copy_output::Bool = false)
    return LLMDispatchConfig(
        ThinkLevel(think),
        dry_run,
        String(schema_content),
        normalize_output,
        copy_output,
    )
end

provider_kwargs(cfg::LLMDispatchConfig) =
    if cfg.dry_run && !isempty(cfg.schema_content)
        (think = cfg.think, dry_run = true, schema_content = cfg.schema_content)
    elseif cfg.dry_run
        (think = cfg.think, dry_run = true)
    elseif !isempty(cfg.schema_content)
        (think = cfg.think, schema_content = cfg.schema_content)
    else
        (think = cfg.think,)
    end

normalize_result(result::AbstractString, cfg::LLMDispatchConfig) = cfg.normalize_output ? normalize_output_text(result) : result

function copy_result!(result::AbstractString, cfg::LLMDispatchConfig)
    if !isempty(result) && cfg.copy_output
        clipboard(result)
    end
end

"""
    get_llm_type(llm_name)

Map provider name to concrete LLM type instance.
"""
function get_llm_type(llm_name)
    canonical = resolve_provider_alias(llm_name)
    llm_types = Dict(
        "openai"      => OpenAILLM(),
        "anthropic"   => AnthropicLLM(),
        "google"      => GoogleLLM(),
        "ollama"      => OllamaLLM(),
        "ollama_cloud" => OllamaCloudLLM(),
        "mistral"     => MistralLLM(),
        "openrouter"  => OpenRouterLLM(),
        "deepseek"    => DeepSeekLLM(),
        "cerebras"    => CerebrasLLM(),
        "groq"        => GroqLLM(),
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

    cfg = LLMDispatchConfig(
        think = think,
        dry_run = dry_run,
        normalize_output = normalize_output,
        copy_output = copy,
    )

    result = call_llm(llm_type, system_instruction, input_text, selected_model, temperature; provider_kwargs(cfg)...)
    result = normalize_result(result, cfg)
    copy_result!(result, cfg)
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
    schema_content = haskey(args, "schema_content") ? args["schema_content"] : ""
    if isempty(schema_content) && haskey(args, "schema")
        schema_content = args["schema"]
    end
    if isempty(schema_content) && haskey(args, "scheme")
        @warn "The argument 'scheme' is deprecated or misspelled; please use 'schema' or 'schema_content'."
        schema_content = args["scheme"]
    end
    copy        = args["copy"]
    think       = args["think"]
    dry_run     = get(args, "dry_run", false)

    cfg = LLMDispatchConfig(
        think = think,
        dry_run = dry_run,
        schema_content = schema_content,
        normalize_output = !get(args, "no_normalize", false),
        copy_output = copy,
    )

    result = call_llm(llm_type, system_instruction, input_text, model, temperature, attach_file; provider_kwargs(cfg)...)
    result = normalize_result(result, cfg)
    copy_result!(result, cfg)
    return result
end
