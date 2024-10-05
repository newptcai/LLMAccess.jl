using LLMAccess
using Test

@testset "LLMAccess.jl" begin
    # Write your tests here.
    system_prompt = """
    Please repeat what ever the input text is.
    Do not return anything else.
    """

    text = "Hello, World! This is a funny test."

    @test LLMAccess.call_llm("google", text, system_prompt) |> rstrip == text

    @test LLMAccess.call_llm("openai", text, system_prompt) |> rstrip == text

    @test LLMAccess.call_llm("anthropic", text, system_prompt) |> rstrip == text

    @test LLMAccess.call_llm("mistral", text, system_prompt) |> rstrip == text

    @test LLMAccess.call_llm("ollama", text, system_prompt) |> rstrip == text
end
