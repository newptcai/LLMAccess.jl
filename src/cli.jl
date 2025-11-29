"""
    create_default_settings()

Create a default ArgParseSettings for LLMAccess CLIs.
"""
function create_default_settings()
    return ArgParseSettings(
        description = "Process text using various LLM providers.",
        add_version = true,
    )
end

"""
    parse_commandline(settings; require_input=true)

Parse CLI arguments, applying sensible defaults and alias handling.
"""
function parse_commandline(
    settings = create_default_settings();
    require_input::Bool = true,
    omit_args::Vector{String} = String[]
)
    llm   = resolve_provider_alias(get_default_llm())
    model = get_default_model(llm)
    @debug "parse_commandline: Initial default_llm='$llm', initial default_model='$model' (before parsing args)"
    return parse_commandline(settings, llm, model; require_input=require_input, omit_args=omit_args)
end

"""
    parse_commandline(settings, default_llm; require_input=true)
"""
function parse_commandline(
    settings,
    default_llm::String;
    require_input = true,
    omit_args::Vector{String} = String[]
)
    canonical_llm = resolve_provider_alias(default_llm)
    default_model = get_default_model(canonical_llm)
    @debug "parse_commandline: Using provided default_llm='$default_llm', derived default_model='$default_model'"
    return parse_commandline(settings, canonical_llm, default_model; require_input=require_input, omit_args=omit_args)
end

"""
    parse_commandline(settings, default_llm, default_model; require_input=true)
"""
function parse_commandline(
    settings,
    default_llm::String,
    default_model::String;
    require_input::Bool = true,
    omit_args::Vector{String} = String[]
)
    omit = Set(omit_args)
    if !("llm" in omit)
        @add_arg_table! settings begin
            "--llm", "-l"; help = "LLM provider to use (aliases: g, oa, an, ol, m, or, ds)"; default = default_llm
        end
    end
    if !("model" in omit)
        @add_arg_table! settings begin
            "--model", "-m"; help = "Specific model to use"; default = default_model
        end
    end
    if !("file" in omit)
        @add_arg_table! settings begin
            "--file", "-f"; help = "Path to input file to process"; default = ""
        end
    end
    if !("attachment" in omit)
        @add_arg_table! settings begin
            "--attachment", "-a"; help = "Path to file attachment"; default = ""
        end
    end
    if !("schema-file" in omit)
        @add_arg_table! settings begin
            "--schema-file"; help = "Path to a JSON schema file for the response"; default = ""
        end
    end
    if !("schema" in omit)
        @add_arg_table! settings begin
            "--schema"; help = "JSON schema for the response as a string"; default = ""
        end
    end
    if !("temperature" in omit)
        @add_arg_table! settings begin
            "--temperature", "-t"; help = "Sampling temperature (0.0-2.0)"; arg_type = Float64; default = get_default_temperature()
        end
    end
    if !("debug" in omit)
        @add_arg_table! settings begin
            "--debug", "-d"; help = "Enable debug logging"; action = :store_true
        end
    end
    if !("copy" in omit)
        @add_arg_table! settings begin
            "--copy", "-c"; help = "Copy response to clipboard"; action = :store_true
        end
    end
    if !("think" in omit)
        @add_arg_table! settings begin
            "--think", "-k"; help = "Reasoning level: -1=auto, 0=none, 1=minimal, 2=low, 3=medium, 4=high."; arg_type = Int; default = 0
        end
    end
    if !("no_normalize" in omit)
        @add_arg_table! settings begin
            "--no-normalize"; help = "Disable punctuation normalization (dashes/quotes)"; dest_name = "no_normalize"; action = :store_true
        end
    end
    if !("alias" in omit)
        @add_arg_table! settings begin
            "--alias"; help = "Print all model aliases and exit"; action = :store_true
        end
    end
    if !("providers" in omit)
        @add_arg_table! settings begin
            "--providers"; help = "Print supported LLM providers (valid --llm choices) and exit"; action = :store_true
        end
    end
    if !("llm-alias" in omit)
        @add_arg_table! settings begin
            "--llm-alias"; help = "Print provider aliases for --llm and exit"; dest_name = "llm_alias"; action = :store_true
        end
    end
    if !("dry_run" in omit)
        @add_arg_table! settings begin
            "--dry-run"; help = "Print JSON payload and do not send"; dest_name = "dry_run"; action = :store_true
        end
    end
    if !("input_text" in omit)
        @add_arg_table! settings begin
            "input_text"; help = "Input text/prompt (reads from stdin if empty)"; required = false
        end
    end

    args = parse_args(settings)

    defaults = Dict(
        "llm" => default_llm,
        "model" => default_model,
        "file" => "",
        "attachment" => "",
        "schema-file" => "",
        "schema" => "",
        "temperature" => get_default_temperature(),
        "debug" => false,
        "copy" => false,
        "think" => 0,
        "no_normalize" => false,
        "alias" => false,
        "providers" => false,
        "llm_alias" => false,
        "dry_run" => false,
        "input_text" => nothing,
    )
    for (k, v) in defaults
        args[k] = get(args, k, v)
    end

    let think_level = args["think"]
        allowed_levels = [-1, 0, 1, 2, 3, 4]
        if !(think_level in allowed_levels)
            println(stderr, "Invalid --think/-k value: got $(think_level), expected one of $(allowed_levels)")
            exit(2)
        end
    end

    @debug "parse_commandline: Args after parse_args: llm='$(args["llm"])', model='$(args["model"])'"

    if get(args, "llm_alias", false)
        keys_sorted = sort!(collect(keys(PROVIDER_ALIASES)))
        for k in keys_sorted
            println("$(k) => $(PROVIDER_ALIASES[k])")
        end
        exit(0)
    end

    if get(args, "alias", false)
        keys_sorted = sort!(collect(keys(MODEL_ALIASES)))
        for k in keys_sorted
            println("$(k) => $(MODEL_ALIASES[k])")
        end
        exit(0)
    end

    if get(args, "providers", false)
        providers = sort!(collect(get_llm_list()))
        println.(providers)
        exit(0)
    end

    if !isempty(args["schema"]) && !isempty(args["schema-file"])
        error("Both --schema and --schema-file cannot be provided at the same time.")
    end

    schema_content = ""
    if !isempty(args["schema"])
        schema_content = args["schema"]
    elseif !isempty(args["schema-file"])
        schema_content = read(args["schema-file"], String)
    end
    args["schema_content"] = schema_content

    if isnothing(args["input_text"]) && require_input
        args["input_text"] = chomp(read(stdin, String))
    end

    # Canonicalize provider early so defaults and downstream code align
    args["llm"] = resolve_provider_alias(args["llm"])

    if args["llm"] != default_llm && args["model"] == default_model
        original_model_before_llm_switch_default = args["model"]
        args["model"] = get_default_model(args["llm"])  # args["llm"] is canonical now
        @debug "parse_commandline: LLM changed from '$default_llm' to '$(args["llm"])'. Model was '$original_model_before_llm_switch_default' -> default for new LLM: '$(args["model"])'"
    end
    @debug "parse_commandline: Final model name from parse_commandline (before alias resolution in call_llm): '$(args["model"])'"

    begin
        resolved_model = resolve_model_alias(args["model"])
        suggested_think = default_think_for_model(resolved_model)
        if args["think"] == 0 && suggested_think != ThinkNone
            args["think"] = Int(suggested_think)
            @debug "parse_commandline: Applying model-based default think" resolved_model suggested_think
        end
        # Convert sentinel value to 0 for consistency
        if args["think"] == -999
            args["think"] = 0
        end
    end

    if args["debug"]
        current_logger = global_logger()
        if !(isa(current_logger, ConsoleLogger) && current_logger.min_level == Logging.Debug)
            global_logger(ConsoleLogger(stderr, Logging.Debug))
            @info "Debug mode enabled by command line flag."
        else
            @debug "Debug mode was already enabled."
        end
    end

    return args
end

"""
    run_cli(f; settings=nothing, debug_getter=() -> false)

Run a CLI entrypoint and handle common errors consistently.
"""
function run_cli(f::Function; settings=nothing, debug_getter::Function=() -> false)
    try
        Base.exit_on_sigint(false)
    catch
    end

    try
        return f()
    catch err
        bt = catch_backtrace()
        debug_mode::Bool = false
        try
            debug_mode = debug_getter()
        catch
            debug_mode = false
        end

        if err isa TaskFailedException
            cause = try err.task.exception catch; nothing end
            if cause isa InterruptException
                println(stderr, "Cancelled.")
                exit(130)
            end
        end

        if err isa InterruptException
            println(stderr, "Cancelled.")
            exit(130)
        elseif err isa ArgParse.ArgParseError
            println(stderr, "Invalid arguments: ", sprint(showerror, err))
            if settings !== nothing
                try
                    ArgParse.show_help(settings; exit_after=false)
                catch
                    try
                        ArgParse.show_help(settings)
                    catch
                    end
                end
            end
            exit(2)
        elseif err isa KeyError
            missing_key = try string(err.key) catch; "<unknown>" end
            if occursin("_API_KEY", missing_key)
                println(stderr, "Missing API key: $(missing_key). Set it and retry. See README.")
            else
                println(stderr, "Missing required key: $(missing_key).")
            end
            if debug_mode
                showerror(stderr, err, bt); println(stderr)
            else
                println(stderr, "Run with --debug for stack trace.")
            end
            exit(1)
        else
            println(stderr, "Error: ", sprint(showerror, err))
            if debug_mode
                showerror(stderr, err, bt); println(stderr)
            else
                println(stderr, "Run with --debug for stack trace.")
            end
            exit(1)
        end
    end
end

"""
    run_cli_with_args(f, settings; parser=parse_commandline)

Convenience wrapper for CLI scripts: parse arguments with `parser(settings)`,
wire the resulting dict into the standard `run_cli` error handler, and execute
`f(args)` with consistent debug flag detection.
"""
function run_cli_with_args(
    f::Function,
    settings;
    parser::Function = parse_commandline,
)
    args_ref = Ref{Any}(nothing)
    return run_cli(() -> begin
        args = parser(settings)
        args_ref[] = args
        f(args)
    end; settings=settings,
         debug_getter=() -> begin
             parsed = args_ref[]
             parsed === nothing ? false : get(parsed, "debug", false)
         end)
end
