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

    args = parse_commandline(custom_settings)

    try
        result = call_llm(
            system_instruction,
            args
        )

        @assert rstrip(result)==rstrip(args["input_text"])
        println("""
                LLM returned:

                $(result)
                """)
        exit(0)
    catch err
        @error "Echo test failed" exception=(err, catch_backtrace())
        exit(1)
    end
end

@main
