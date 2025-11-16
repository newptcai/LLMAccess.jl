#!/bin/bash

# This script runs a test of the --schema functionality with the Mistral LLM.

# Exit immediately if a command exits with a non-zero status.
set -e

# Define the project root directory
PROJECT_ROOT=$(git rev-parse --show-toplevel)

# Define the path to the ask.jl script
ASK_JL_SCRIPT="$PROJECT_ROOT/script/ask.jl"

# Define the prompt
PROMPT="Who wrote To Kill a Mockingbird?"

TEST_SCHEMA='{
    "schema": {
      "properties": {
        "name": {
          "title": "Name",
          "type": "string"
        },
        "authors": {
          "items": {
            "type": "string"
          },
          "title": "Authors",
          "type": "array"
        }
      },
      "required": ["name", "authors"],
      "title": "Book",
      "type": "object",
      "additionalProperties": false
    },
    "name": "book",
    "strict": true
}'

# Run the command
# julia --project="$PROJECT_ROOT" "$ASK_JL_SCRIPT" --llm mistral --schema "$TEST_SCHEMA" "$PROMPT" | jq

# Run the command for openrouter
julia --project="$PROJECT_ROOT" "$ASK_JL_SCRIPT" --llm openrouter --model "openai/gpt-4.1-nano" --schema "$TEST_SCHEMA" "$PROMPT" | jq

# Run the command for anthropic
# julia --project="$PROJECT_ROOT" "$ASK_JL_SCRIPT" --llm anthropic --model "claude-sonnet-4.5" --schema "$TEST_SCHEMA" "$PROMPT" | jq

# Run the command for deepseek
# julia --project="$PROJECT_ROOT" "$ASK_JL_SCRIPT" --llm deepseek --model "deepseek-chat" --schema "$TEST_SCHEMA" "$PROMPT" | jq
