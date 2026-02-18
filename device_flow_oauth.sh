#!/bin/bash
# OAuth2 Device Flow for NVIDIA SSO
# No redirect URI needed - user enters code on separate device

CLIENT_ID="iPY1HAJZ3oFvPtLdJNeMrm1KB_M7YHRf_jbxi7WwbzM"
TOKEN_ENDPOINT="https://stg.login.nvidia.com/token"
DEVICE_AUTH_ENDPOINT="https://stg.login.nvidia.com/device/authorize"
USERINFO_ENDPOINT="https://stg.login.nvidia.com/userinfo"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "OAuth2 Device Flow - NVIDIA SSO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Generate unique device ID
DEVICE_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "device-$(date +%s)")

echo "Step 1: Initiating device flow..."
echo "Device ID: $DEVICE_ID"
echo ""

# Start device flow
DEVICE_RESPONSE=$(curl -s -X POST "$DEVICE_AUTH_ENDPOINT" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "scope=openid profile email authz" \
  -d "device_id=$DEVICE_ID" \
  -d "display_name=CLI Device")

# Check if successful
if ! echo "$DEVICE_RESPONSE" | jq -e '.user_code' > /dev/null 2>&1; then
    echo "❌ Failed to start device flow:"
    echo "$DEVICE_RESPONSE" | jq
    exit 1
fi

# Extract values
USER_CODE=$(echo "$DEVICE_RESPONSE" | jq -r '.user_code')
DEVICE_CODE=$(echo "$DEVICE_RESPONSE" | jq -r '.device_code')
VERIFICATION_URI=$(echo "$DEVICE_RESPONSE" | jq -r '.verification_uri')
VERIFICATION_URI_COMPLETE=$(echo "$DEVICE_RESPONSE" | jq -r '.verification_uri_complete')
EXPIRES_IN=$(echo "$DEVICE_RESPONSE" | jq -r '.expires_in')
INTERVAL=$(echo "$DEVICE_RESPONSE" | jq -r '.interval // 5')

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Complete login in your browser"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  User Code:  $USER_CODE"
echo ""
echo "  Open this URL in your browser:"
echo "  $VERIFICATION_URI_COMPLETE"
echo ""
echo "  Or go to: $VERIFICATION_URI"
echo "  And enter code: $USER_CODE"
echo ""
echo "  Code expires in: $EXPIRES_IN seconds"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try to open browser automatically
if command -v open &> /dev/null; then
    open "$VERIFICATION_URI_COMPLETE" 2>/dev/null
elif command -v xdg-open &> /dev/null; then
    xdg-open "$VERIFICATION_URI_COMPLETE" 2>/dev/null
fi

# Try to copy URL to clipboard
if command -v pbcopy &> /dev/null; then
    echo "$VERIFICATION_URI_COMPLETE" | pbcopy
    echo "✓ URL copied to clipboard"
elif command -v xclip &> /dev/null; then
    echo "$VERIFICATION_URI_COMPLETE" | xclip -selection clipboard
    echo "✓ URL copied to clipboard"
fi

echo ""
echo "Step 3: Polling for token (every $INTERVAL seconds)..."
echo ""

# Calculate expiration time
EXPIRE_TIME=$(($(date +%s) + EXPIRES_IN))
POLL_COUNT=0

while true; do
    POLL_COUNT=$((POLL_COUNT + 1))
    
    # Check if expired
    CURRENT_TIME=$(date +%s)
    if [ $CURRENT_TIME -gt $EXPIRE_TIME ]; then
        echo ""
        echo "❌ Device code expired after $EXPIRES_IN seconds"
        echo "Run the script again to get a new code"
        exit 1
    fi
    
    # Poll token endpoint
    TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
      -d "client_id=$CLIENT_ID" \
      -d "device_code=$DEVICE_CODE")
    
    # Check if we got a token
    if echo "$TOKEN_RESPONSE" | jq -e '.access_token' > /dev/null 2>&1; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✓ SUCCESS! Token received after $POLL_COUNT polls"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Extract tokens
        ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
        ID_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.id_token // empty')
        EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | jq -r '.expires_in')
        
        echo "Access Token: ${ACCESS_TOKEN:0:50}..."
        echo "Expires in: $EXPIRES_IN seconds"
        
        # Save to files
        echo "$ACCESS_TOKEN" > access_token.txt
        echo "$TOKEN_RESPONSE" > token_response.json
        
        echo ""
        echo "✓ Token saved to: access_token.txt"
        echo "✓ Full response saved to: token_response.json"
        
        # Export for current shell
        export ACCESS_TOKEN
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Step 4: Testing token..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Test with userinfo endpoint
        USER_INFO=$(curl -s "$USERINFO_ENDPOINT" \
          -H "Authorization: Bearer $ACCESS_TOKEN")
        
        echo "User Info:"
        echo "$USER_INFO" | jq
        
        EMAIL=$(echo "$USER_INFO" | jq -r '.email // "N/A"')
        echo ""
        echo "✓ Authenticated as: $EMAIL"
        
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✓ All done!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "To use token in other commands:"
        echo "  export ACCESS_TOKEN=\$(cat access_token.txt)"
        echo ""
        echo "Example:"
        echo "  curl -H \"Authorization: Bearer \$ACCESS_TOKEN\" https://stg.login.nvidia.com/userinfo"
        
        break
        
    elif echo "$TOKEN_RESPONSE" | jq -e '.error' | grep -q "authorization_pending"; then
        # Still waiting for user to complete login
        REMAINING=$((EXPIRE_TIME - CURRENT_TIME))
        printf "\r⏳ Poll #%d - Waiting for user login... (%ds remaining)" $POLL_COUNT $REMAINING
        sleep "$INTERVAL"
        
    elif echo "$TOKEN_RESPONSE" | jq -e '.error' | grep -q "slow_down"; then
        # Polling too fast, increase interval
        echo ""
        echo "⚠️  Polling too fast, slowing down..."
        INTERVAL=$((INTERVAL + 5))
        sleep "$INTERVAL"
        
    elif echo "$TOKEN_RESPONSE" | jq -e '.error' | grep -q "expired_token"; then
        echo ""
        echo "❌ Device code expired"
        echo "Run the script again to get a new code"
        exit 1
        
    else
        echo ""
        echo "❌ Unexpected error:"
        echo "$TOKEN_RESPONSE" | jq
        exit 1
    fi
done
