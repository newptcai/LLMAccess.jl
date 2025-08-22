#!/usr/bin/env -S julia -O 0 --compile=min --project="${SRC_DIR}/bin/"

using LLMAccess
using ArgParse
using Logging

function main(_)
    # Define the system prompt
    system_instruction = ""

    custom_settings = ArgParseSettings(
        prog = "ask.jl",
        description = "Use LLM to answer simple question.",
        add_version = true,
        version = "v1.0.0",
    )

    # Use centralized error handling from LLMAccess.run_cli.
    #
    # We wrap the main body in an anonymous zero-argument function and pass it to `run_cli`.
    # `run_cli` executes the function and traps common errors to print friendly messages
    # and exit with consistent codes (e.g., 2 for usage, 130 for Ctrl-C).
    #
    # We want the error handler to know whether `--debug` was provided so it can
    # decide whether to show a stack trace. Since `--debug` is only known AFTER
    # parsing, we store the parsed args in a `Ref` cell that both the main body and
    # the `debug_getter` closure can access.
    #
    # Why `Ref`? In Julia, assigning to a local variable inside a closure rebinds
    # that variable within the closure’s scope and doesn't mutate an outer variable.
    # Using `args_ref[] = args` mutates the referenced object instead, so the
    # `debug_getter` (a separate closure) can reliably read it.
    args_ref = Ref{Any}(nothing)
    run_cli(() -> begin
        # 1) Parse CLI args (provides defaults, reads stdin when needed, etc.)
        args = parse_commandline(custom_settings)
        args_ref[] = args

        # 2) Call the provider with parsed args and print the result.
        result = call_llm(system_instruction, args)

        print(result)
        if !isempty(result) && result[end] != '\n'
            print("\n")
        end
        nothing
    end; settings=custom_settings,
         # Tell `run_cli` how to determine debug mode. If parsing failed, `args_ref[]`
         # will still be `nothing`, so we default to `false` to avoid extra noise.
         debug_getter=() -> begin
             a = args_ref[]
             a === nothing ? false : get(a, "debug", false)
         end)
end

@main
