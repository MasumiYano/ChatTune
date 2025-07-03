#!/bin/bash

API_KEY="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"
MODEL="gpt-4o"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # no color

# Global variables
messages=""

echo_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

check_dependencies() {
    local missing_deps=()

    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo_color "$RED" "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them and try again."
        exit 1
    fi
}

validate_api_key() {
    if [[ -z "$API_KEY" || "$API_KEY" == "your-openai-api-key" ]]; then
        echo_color "$RED" "Error: Please set your OpenAI API key in the script."
        exit 1
    fi
}

cleanup() {
    # Kill any background processes
    if [ -f /tmp/dj_visualizer_pid ]; then
        local pid=$(cat /tmp/dj_visualizer_pid 2>/dev/null)
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null
        fi
        rm -f /tmp/dj_visualizer_pid
    fi
    
    rm -f /tmp/dj_current_songs
    echo_color "$GREEN" "Until we see each other...👋"
    exit 0
}

create_system_prompt() {
    local system_content='You are a dope DJ. You know everything about music, and you are just that chill dude who always wants to recommend people good songs based on the interaction. You also pick up little cues in the prompt to deeply think of their intention and desire, and suggest songs based around that as well.

When you are recommending songs, you should follow this template:

<Your dope response to my chat>
<Your dope opening to introduce songs>

1. <song rec 1>
2. <song rec 2>
....
n. <song rec n>

<Your dope ending that shows you are the chillest dude ever.>

Keep your responses conversational and friendly.'
    
    messages=$(jq -n -c --arg content "$system_content" '[{
        "role": "system",
        "content": $content
    }]')
}

call_api() {
    local user_message="$1"
    
    echo_color "$YELLOW" "🤖 DJ is thinking..."
    
    # Add user message to conversation
    messages=$(echo "$messages" | jq -c --arg content "$user_message" \
        '. + [{"role": "user", "content": $content}]')
    
    # Create API payload
    local payload=$(echo "$messages" | jq -c --arg model "$MODEL" '{
        "model": $model,
        "messages": .,
        "max_tokens": 1000,
        "temperature": 0.8
    }')
    
    # Make API call
    local response=$(curl -s https://api.openai.com/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "$payload")
    
    # Extract response and handle errors
    local reply=$(echo "$response" | jq -r '.choices[0].message.content // empty')
    local error_msg=$(echo "$response" | jq -r '.error.message // empty')
    
    if [[ -n "$error_msg" ]]; then
        echo_color "$RED" "❌ API Error: $error_msg"
        return 1
    fi
    
    if [[ -z "$reply" || "$reply" == "null" ]]; then
        echo_color "$YELLOW" "⚠️ No response received from API"
        return 1
    fi
    
    # Display response
    echo_color "$CYAN" "🤖 DJ:"
    echo "$reply"
    echo ""  # Add spacing
    
    # Add assistant response to conversation
    messages=$(echo "$messages" | jq -c --arg content "$reply" \
        '. + [{"role": "assistant", "content": $content}]')
    
    # Check if response contains songs and offer to play
    if echo "$reply" | grep -q -E '^[0-9]+\.'; then
        offer_music_playback "$reply"
    fi
    
    return 0
}

offer_music_playback() {
    local songs_response="$1"
    
    echo_color "$PURPLE" "🎵 Play these songs in the visualizer? [y/n]"
    echo -ne "${PURPLE}Choice: ${NC}"
    read -r choice
    echo ""  # Add spacing after choice
    
    case "$choice" in
        y|yes|Y|YES)
            # Send songs to visualizer (if it exists)
            echo "$songs_response" > /tmp/dj_current_songs 2>/dev/null
            echo_color "$GREEN" "🎵 Music queued!🎶"
            python3 "${SCRIPT_DIR}/scripts/play_music.py"
            ;;
        *)
            echo_color "$CYAN" "Cool, just vibing with the recommendations! 🎶"
            ;;
    esac
    
    echo ""  # Add spacing
}

show_help() {
    echo_color "$CYAN" "DJ Chat Bot - Commands:"
    echo_color "$GREEN" "  Normal chat - Just type your music requests"
    echo_color "$GREEN" "  help        - Show this help"
    echo_color "$GREEN" "  clear       - Clear chat history"
    echo_color "$GREEN" "  exit/quit   - Exit the application"
    echo ""
}

handle_special_commands() {
    local input="$1"
    
    case "$input" in
        "help"|"h"|"?")
            show_help
            return 0
            ;;
        "clear"|"cls")
            clear
            echo_color "$CYAN" "🎤 DJ Chat Bot - Music Recommendation & Visualizer"
            echo_color "$YELLOW" "═══════════════════════════════════════════════════"
            echo ""
            create_system_prompt
            echo_color "$YELLOW" "🔄 Chat history cleared!"
            echo ""
            return 0
            ;;
        "exit"|"quit"|"q")
            cleanup
            ;;
        *)
            return 2  # Not a special command
            ;;
    esac
}

main_loop() {
    while true; do
        echo -ne "${GREEN}You: ${NC}"
        read -r user_input
        echo ""  # Add spacing after input
        
        # Handle special commands
        handle_special_commands "$user_input"
        local cmd_result=$?
        
        if [ $cmd_result -eq 0 ]; then
            # Special command handled, continue loop
            continue
        fi
        
        # Regular chat - call API
        if ! call_api "$user_input"; then
            echo_color "$RED" "Failed to get response. Try again."
            echo ""
        fi
    done
}

main() {
    # Set up signal handlers for cleanup
    trap cleanup EXIT
    trap cleanup SIGINT
    trap cleanup SIGTERM
    
    # Clear screen and show header
    clear
    echo_color "$CYAN" "🎤 DJ Chat Bot - Music Recommendation & Visualizer"
    echo_color "$YELLOW" "═══════════════════════════════════════════════════"
    echo ""
    
    # Validate environment
    echo_color "$BLUE" "Checking environment..."
    check_dependencies
    validate_api_key
    echo_color "$GREEN" "✅ Environment OK"
    echo ""
    
    # Initialize chat
    create_system_prompt
    
    # Show welcome message
    echo_color "$CYAN" "🎵 Welcome to DJ Chat! I'm here to recommend awesome music! 🎵"
    echo_color "$YELLOW" "Type 'help' for commands or just start chatting about music!"
    echo ""
    
    # Start main chat loop
    main_loop
}

main "$@"
