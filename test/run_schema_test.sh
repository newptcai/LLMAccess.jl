#!/bin/bash

# This script runs a test of the --schema functionality with the Mistral LLM.

# Exit immediately if a command exits with a non-zero status.
set -e

# Define the project root directory
PROJECT_ROOT=$(git rev-parse --show-toplevel)

# Define the path to the ask.jl script
ASK_JL_SCRIPT="$PROJECT_ROOT/script/ask.jl"

# Define the path to the test schema
TEST_SCHEMA="$PROJECT_ROOT/test/test_schema.json"

# Define the prompt
PROMPT="Who wrote To Kill a Mockingbird?"

# Run the command
# julia --project="$PROJECT_ROOT" "$ASK_JL_SCRIPT" --llm mistral --schema-file "$TEST_SCHEMA" "$PROMPT" | jq

# Run the command for openrouter
# julia --project="$PROJECT_ROOT" "$ASK_JL_SCRIPT" --llm openrouter --model "openai/gpt-oss-120b" --schema-file "$TEST_SCHEMA" "$PROMPT" | jq

# Run the command for anthropic
ANTHROPIC_SCHEMA='{
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
}'
julia --project="$PROJECT_ROOT" "$ASK_JL_SCRIPT" -d --llm anthropic --model "claude-sonnet-4-5-20250929" --schema "$ANTHROPIC_SCHEMA" "$PROMPT" | jq
