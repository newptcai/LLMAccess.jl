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
        response = LLMAccess.call_llm(llm, system_instruction, text) |> rstrip
        @show response
        @test response == text
    end
    
    test_llm(get_llm_type("google"))
    test_llm(get_llm_type("openai"))
    test_llm(get_llm_type("anthropic"))
    test_llm(get_llm_type("mistral"))
    test_llm(get_llm_type("ollama"))
    test_llm(get_llm_type("openrouter"))
    test_llm(get_llm_type("groq"))
    test_llm(get_llm_type("deepseek"))

    # Test specific Google model
    println("Testing Google model flash")
    google_flash_response = LLMAccess.call_llm(
        "google", 
        system_instruction,
        text,
        model="flash",
        thinking_budget=0 # Explicitly set thinking_budget for the test
    )
    @show google_flash_response
    @test google_flash_response |> rstrip == text

    # Test error handling for non-existent model (Mistral example)
    println("Testing Mistral with non-existent model")
    non_existent_model = "non-existent-model-abcxyz"
    @test_logs (:error, r"HTTP request failed") begin
        err = @test_throws ErrorException LLMAccess.call_llm(
            "mistral",
            system_instruction,
            text,
            model=non_existent_model
        )
        @test occursin(non_existent_model, err.msg)
        @test occursin(r"status (404|400)", err.msg)
    end
end
