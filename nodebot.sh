#!/bin/bash

# Function to handle the API request
send_request() {
    local message="$1"
    local api_key="$2"
    local api_url="$3"
    local proxy="$4"  # اضافه کردن پارامتر پروکسی

    while true; do
        # Prepare the JSON payload
        json_data=$(cat <<EOF
{
    "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "$message"}
    ]
}
EOF
        )

        # Send the request using curl with proxy and capture both the response and status code
        if [ -n "$proxy" ]; then
            response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
                -H "Authorization: Bearer $api_key" \
                -H "Accept: application/json" \
                -H "Content-Type: application/json" \
                --proxy "$proxy" \
                -d "$json_data")
        else
            response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
                -H "Authorization: Bearer $api_key" \
                -H "Accept: application/json" \
                -H "Content-Type: application/json" \
                -d "$json_data")
        fi

        # Extract the HTTP status code from the response
        http_status=$(echo "$response" | tail -n 1)
        body=$(echo "$response" | head -n -1)

        if [[ "$http_status" -eq 200 ]]; then
            # Check if the response is valid JSON
            echo "$body" | jq . > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                # Print the question and response content
                echo "✅ [SUCCESS] API: $api_url | Message: '$message'"
                response_message=$(echo "$body" | jq -r '.choices[0].message.content')
                echo "Question: $message"
                echo "Response: $response_message"
                break  # Exit loop if request was successful
            else
                echo "⚠️ [ERROR] Invalid JSON response! API: $api_url"
                echo "Response Text: $body"
            fi
        else
            echo "⚠️ [ERROR] API: $api_url | Status: $http_status | Retrying..."
            sleep 2
        fi
    done
}

# Define a list of predefined messages
user_messages=(
    "What color is a banana"
    "How many fingers do you have on one hand?"
    # ... بقیه پیام‌ها ...
)

# Ask the user to input API Key, Domain URL, and Proxy
echo -n "Enter your API Key: "
read api_key
echo -n "Enter the Domain URL: "
read api_url
echo -n "Enter the Proxy URL (e.g., http://proxy:port or leave empty for no proxy): "
read proxy

# Exit if the API Key or URL is empty
if [ -z "$api_key" ] || [ -z "$api_url" ]; then
    echo "Error: Both API Key and Domain URL are required!"
    exit 1
fi

# Set number of threads to 1 (default)
num_threads=1
echo "✅ Using 1 thread..."

# Function to run the single thread
start_thread() {
    while true; do
        # Pick a random message from the predefined list
        random_message="${user_messages[$RANDOM % ${#user_messages[@]}]}"
        send_request "$random_message" "$api_key" "$api_url" "$proxy"  # ارسال پروکسی به تابع
    done
}

# Start the single thread
start_thread &

# Wait for the thread to finish (this will run indefinitely)
wait

# Graceful exit handling (SIGINT, SIGTERM)
trap "echo -e '\n🛑 Process terminated. Exiting gracefully...'; exit 0" SIGINT SIGTERM
