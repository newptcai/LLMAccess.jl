#!/usr/bin/env -S julia -O 0 --compile=min --project="${SRC_DIR}/bin/"

using LLMAccess
using ArgParse

function main(_)
    # Write your tests here.
    system_instruction = """
    Please repeat what ever the input text is.
    Do not return anything else.
    """

    custom_settings = ArgParseSettings(
        prog = "echo.jl",
        description = "My awesome LLM echo chamber",
        add_version = true,
        version = "v1.0.0"
    )

    # Mirror ask.jl: delegate error handling and Ctrl+C to run_cli
    args_ref = Ref{Any}(nothing)
    run_cli(() -> begin
        args = parse_commandline(custom_settings)
        args_ref[] = args

        result = call_llm(system_instruction, args)

        @assert rstrip(result) == rstrip(args["input_text"])
        println("""
                LLM returned:

                $(result)
                """)
        nothing
    end; settings=custom_settings,
         debug_getter=() -> begin
             a = args_ref[]
             a === nothing ? false : get(a, "debug", false)
         end)
end

@main
