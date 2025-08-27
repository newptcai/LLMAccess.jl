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

    @testset "Command-line parsing for --think/-k" begin                                                                                                                                        
        original_ARGS = copy(ARGS)                                                                                                                                                              
        try                                                                                                                                                                                     
            # Test case 1: No --think/-k flag; default depends on model.
            # Default LLM is google (gemini-*), so default think should be -1 (dynamic)
            empty!(ARGS)                                                                                                                                                                        
            settings = LLMAccess.create_default_settings()                                                                                                                                      
            # We must not require input, otherwise it will try to read from stdin and hang                                                                                                      
            parsed_args = LLMAccess.parse_commandline(settings, require_input=false)                                                                                                            
            @test parsed_args["think"] == -1                                                                                                                                                    
                                                                                                                                                                                                
            # Test case 2: -k with value                                                                                                                                                        
            empty!(ARGS)                                                                                                                                                                        
            push!(ARGS, "-k", "1500")                                                                                                                                                           
            settings = LLMAccess.create_default_settings()                                                                                                                                      
            parsed_args = LLMAccess.parse_commandline(settings, require_input=false)                                                                                                            
            @test parsed_args["think"] == 1500                                                                                                                                                  
                                                                                                                                                                                                
            # Test case 3: --think with value                                                                                                                                                   
            empty!(ARGS)                                                                                                                                                                        
            push!(ARGS, "--think", "500")                                                                                                                                                       
            settings = LLMAccess.create_default_settings()                                                                                                                                      
            parsed_args = LLMAccess.parse_commandline(settings, require_input=false)                                                                                                            
            @test parsed_args["think"] == 500                                                                                                                                                   
                                                                                                                                                                                                
            # Test case 4: -k with negative value                                                                                                                                                   
            empty!(ARGS)                                                                                                                                                                        
            push!(ARGS, "-k", "-1")                                                                                                                                                       
            settings = LLMAccess.create_default_settings()                                                                                                                                      
            parsed_args = LLMAccess.parse_commandline(settings, require_input=false)                                                                                                            
            @test parsed_args["think"] == -1
                                                                                                                                                                                                
            # Test case 5: Positional argument should still be parsed                                                                                                                           
            empty!(ARGS)                                                                                                                                                                        
            push!(ARGS, "--think", "750", "my prompt")                                                                                                                                          
            settings = LLMAccess.create_default_settings()                                                                                                                                      
            parsed_args = LLMAccess.parse_commandline(settings, require_input=false)                                                                                                            
            @test parsed_args["think"] == 750                                                                                                                                                   
            @test parsed_args["input_text"] == "my prompt"                                                                                                                                      
        finally                                                                                                                                                                                 
            empty!(ARGS)                                                                                                                                                                        
            append!(ARGS, original_ARGS)                                                                                                                                                        
        end                                                                                                                                                                                     
    end  
end
