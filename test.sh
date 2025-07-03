#!/bin/bash

echo "🎤 DJ Chat Bot Test"
echo "==================="

# Basic dependency check
echo "Checking dependencies..."
command -v curl >/dev/null 2>&1 || { echo "Missing curl"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Missing jq"; exit 1; }
echo "✅ Dependencies OK"

# Simple chat loop
while true; do
    echo -n "You: "
    read -r input
    
    if [[ "$input" == "exit" ]]; then
        break
    fi
    
    echo "🤖 DJ: You said '$input' (API call would happen here)"
done

echo "Goodbye!"
