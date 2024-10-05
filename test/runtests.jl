using LLMAccess
using Test

@testset "LLMAccess.jl" begin
    # Write your tests here.
    system_prompt = """
    Please repeat what ever the input text is.
    Do not return anything else.
    """

    text = "Hello, World! This is a funny test."

    llm = get_llm_type("google")
    @test LLMAccess.call_llm(llm, text, system_prompt) |> rstrip == text

    llm = get_llm_type("openai")
    @test LLMAccess.call_llm(llm, text, system_prompt) |> rstrip == text

    llm = get_llm_type("anthropic")
    @test LLMAccess.call_llm(llm, text, system_prompt) |> rstrip == text

    llm = get_llm_type("mistral")
    @test LLMAccess.call_llm(llm, text, system_prompt) |> rstrip == text

    llm = get_llm_type("ollama")
    @test LLMAccess.call_llm(llm, text, system_prompt) |> rstrip == text
end
