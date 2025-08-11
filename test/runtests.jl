using LLMAccess
using Test

@testset "LLMAccess.jl" begin
    @testset "is_anthropic_thinking_model" begin
        # Opus models - should be true for versions >= 4.0
        @test LLMAccess.is_anthropic_thinking_model("claude-opus-4-20250514") == true
        @test LLMAccess.is_anthropic_thinking_model("claude-opus-4.0-20250514") == true
        @test LLMAccess.is_anthropic_thinking_model("claude-opus-4-1-20250805") == true
        @test LLMAccess.is_anthropic_thinking_model("claude-4-opus-20250514") == true
        @test LLMAccess.is_anthropic_thinking_model("claude-3.0-opus-20240229") == false
        @test LLMAccess.is_anthropic_thinking_model("claude-opus-3-9") == false

        # Sonnet models - should be true for versions >= 3.7
        @test LLMAccess.is_anthropic_thinking_model("claude-sonnet-3-7-20250219") == true
        @test LLMAccess.is_anthropic_thinking_model("claude-3-7-sonnet-20250219") == true
        @test LLMAccess.is_anthropic_thinking_model("claude-sonnet-4-20250514") == true
        @test LLMAccess.is_anthropic_thinking_model("claude-3.5-sonnet-20240620") == false
        @test LLMAccess.is_anthropic_thinking_model("claude-sonnet-3-5-20240620") == false

        # Other models - should be false
        @test LLMAccess.is_anthropic_thinking_model("claude-3-haiku-20240307") == false
        @test LLMAccess.is_anthropic_thinking_model("gpt-4o") == false
        @test LLMAccess.is_anthropic_thinking_model("gemini-1.5-pro") == false
    end

    # Integration tests (can be commented out to avoid API calls)
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
        think=0 # Explicitly set think for the test
    )
    @show google_flash_response
    @test google_flash_response |> rstrip == text

    # Test error handling for non-existent model (Mistral example)
    println("Testing Mistral with non-existent model")
    non_existent_model = "non-existent-model-abcxyz"
    @test_logs (:error, r"HTTP request failed") begin
        try
            LLMAccess.call_llm(
                "mistral",
                system_instruction,
                text,
                model=non_existent_model
            )
            @test false # Should not be reached
        catch err
            @test err isa ErrorException
            @test occursin(non_existent_model, err.msg)
            @test occursin(r"status (404|400)", err.msg)
        end
    end
end
