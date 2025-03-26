using LLMAccess
using Test

@testset "LLMAccess.jl" begin
    # Write your tests here.
    system_instruction = """
    Please repeat what ever the input text is.
    Do not return anything else.
    """

    text = "Hello, World! This is a funny test."

    function test_llm(llm)
        println("Testing LLM $(llm)")
        response = LLMAccess.call_llm(llm, system_instruction, text)
        @show response
        @test response |> rstrip == text
    end
    
    test_llm(get_llm_type("google"))
    test_llm(get_llm_type("openai"))
    test_llm(get_llm_type("anthropic"))
    test_llm(get_llm_type("mistral"))
    test_llm(get_llm_type("ollama"))
    test_llm(get_llm_type("openrouter"))
    test_llm(get_llm_type("groq"))
    test_llm(get_llm_type("deepseek"))
end
