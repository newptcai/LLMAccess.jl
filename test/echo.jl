using LLMAccess
using ArgParse

function main()
    # Write your tests here.
    system_instruction = """
    Please repeat what ever the input text is.
    Do not return anything else.
    """

    custom_settings = ArgParseSettings(
        description = "My awesome LLM echo chamber",
        add_version = true,
        version = "v1.0.0"
    )

    args = parse_commandline(custom_settings)

    println("""
            Calling LLM with:
            -- llm: $(args["llm"])
            -- input_text: $(args["input_text"])
            -- model: $(args["model"])
            -- temperature: $(args["temperature"])
            """)

    llm_type = get_llm_type(args["llm"])
    result = call_llm(llm_type, 
                      args["input_text"],
                      system_instruction,
                      args["model"],
                      args["temperature"])
    @assert rstrip(result)==rstrip(args["input_text"])
    println("""
            LLM returned:

            $(result)
            """)
end

main()
