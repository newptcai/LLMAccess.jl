#!/usr/bin/env -S julia -O 0 --compile=min --startup-file=no --project=@script

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

    # Mirror ask.jl: delegate error handling and Ctrl+C to run_cli_with_args
    run_cli_with_args(custom_settings) do args
        result = call_llm(system_instruction, args)

        println("""
                LLM returned:

                $(result)
                """)
        nothing
    end
end

@main
