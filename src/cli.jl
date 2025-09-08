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
    require_input::Bool = true
)
    llm   = get_default_llm()
    model = get_default_model(llm)
    @debug "parse_commandline: Initial default_llm='$llm', initial default_model='$model' (before parsing args)"
    return parse_commandline(settings, llm, model; require_input=require_input)
end

"""
    parse_commandline(settings, default_llm; require_input=true)
"""
function parse_commandline(
    settings,
    default_llm::String;
    require_input = true
)
    default_model = get_default_model(default_llm)
    @debug "parse_commandline: Using provided default_llm='$default_llm', derived default_model='$default_model'"
    return parse_commandline(settings, default_llm, default_model; require_input=require_input)
end

"""
    parse_commandline(settings, default_llm, default_model; require_input=true)
"""
function parse_commandline(
    settings,
    default_llm::String,
    default_model::String;
    require_input::Bool = true
)
    @add_arg_table! settings begin
        "--llm", "-l"; help = "LLM provider to use"; default = default_llm
        "--model", "-m"; help = "Specific model to use"; default = default_model
        "--file", "-f"; help = "Path to input file to process"; default = ""
        "--attachment", "-a"; help = "Path to file attachment"; default = ""
        "--temperature", "-t"; help = "Sampling temperature (0.0-2.0)"; arg_type = Float64; default = get_default_temperature()
        "--debug", "-d"; help = "Enable debug logging"; action = :store_true
        "--copy", "-c"; help = "Copy response to clipboard"; action = :store_true
        "--think", "-k"; help = "Thinking budget; default varies by model (e.g., Gemini=-1, Sonnet=0)."; arg_type = Int; default = 0
        "--alias", "-A"; help = "Print all model aliases and exit"; action = :store_true
        "--providers"; help = "Print supported LLM providers (valid --llm choices) and exit"; action = :store_true
        "--dry-run", "-D"; help = "Print JSON payload and do not send"; dest_name = "dry_run"; action = :store_true
        "input_text"; help = "Input text/prompt (reads from stdin if empty)"; required = false
    end

    args = parse_args(settings)
    @debug "parse_commandline: Args after parse_args: llm='$(args["llm"])', model='$(args["model"])'"

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

    if isnothing(args["input_text"]) && require_input
        args["input_text"] = chomp(read(stdin, String))
    end

    if args["llm"] != default_llm && args["model"] == default_model
        original_model_before_llm_switch_default = args["model"]
        args["model"] = get_default_model(args["llm"])
        @debug "parse_commandline: LLM changed from '$default_llm' to '$(args["llm"])'. Model was '$original_model_before_llm_switch_default' -> default for new LLM: '$(args["model"])'"
    end
    @debug "parse_commandline: Final model name from parse_commandline (before alias resolution in call_llm): '$(args["model"])'"

    begin
        resolved_model = resolve_model_alias(args["model"])
        suggested_think = default_think_for_model(resolved_model)
        if args["think"] == 0 && suggested_think != 0
            args["think"] = suggested_think
            @debug "parse_commandline: Applying model-based default think" resolved_model suggested_think
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
