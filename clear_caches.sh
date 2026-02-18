#!/bin/bash
# Clear all Talk-to-Data caches on localhost

BASE_URL="http://localhost:8000"
# BASE_URL="https://talk-to-data-agent-service-dev.nvidia.com"

# Get token from environment variable or use default (if set)
if [ -z "$ACCESS_TOKEN" ]; then
    if [ -f "access_token.txt" ]; then
        TOKEN=$(cat access_token.txt)
        echo "Using token from access_token.txt"
    else
        echo "ERROR: ACCESS_TOKEN environment variable not set and access_token.txt not found"
        echo ""
        echo "To get a token:"
        echo "1. Run the device flow authentication"
        echo "2. Export it: export ACCESS_TOKEN=\$(cat access_token.txt)"
        echo "3. Or save it to access_token.txt"
        echo ""
        exit 1
    fi
else
    TOKEN="$ACCESS_TOKEN"
    echo "Using token from ACCESS_TOKEN environment variable"
fi

# Verify token is not empty
if [ -z "$TOKEN" ]; then
    echo "ERROR: Token is empty"
    exit 1
fi

echo "════════════════════════════════════════════════════════════"
echo "Clearing Talk-to-Data Caches on ${BASE_URL}"
echo "════════════════════════════════════════════════════════════"
echo ""

# Clear final output cache (summaries)
echo "1. Clearing final output cache..."
RESPONSE1=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL/admin/cache/clear \
  -H "Content-Type: application/json" \
  -d "{
    \"pattern\": \"nat*\",
    \"confirm\": true,
    \"authorization\": \"Bearer $TOKEN\"
  }")

HTTP_CODE1=$(echo "$RESPONSE1" | tail -n1)
BODY1=$(echo "$RESPONSE1" | sed '$d')

if [ "$HTTP_CODE1" = "200" ] || [ "$HTTP_CODE1" = "201" ]; then
    echo "$BODY1" | jq
else
    echo "ERROR: HTTP $HTTP_CODE1"
    echo "$BODY1" | jq 2>/dev/null || echo "$BODY1"
fi
echo ""

# Clear SQL query cache
echo "2. Clearing SQL query cache..."
RESPONSE2=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL/admin/cache/clear \
  -H "Content-Type: application/json" \
  -d "{
    \"pattern\": \"ttyd*\",
    \"confirm\": true,
    \"authorization\": \"Bearer $TOKEN\"
  }")

HTTP_CODE2=$(echo "$RESPONSE2" | tail -n1)
BODY2=$(echo "$RESPONSE2" | sed '$d')

if [ "$HTTP_CODE2" = "200" ] || [ "$HTTP_CODE2" = "201" ]; then
    echo "$BODY2" | jq
else
    echo "ERROR: HTTP $HTTP_CODE2"
    echo "$BODY2" | jq 2>/dev/null || echo "$BODY2"
fi
echo ""


echo "════════════════════════════════════════════════════════════"
echo "✓ All caches cleared!"
echo "════════════════════════════════════════════════════════════"
