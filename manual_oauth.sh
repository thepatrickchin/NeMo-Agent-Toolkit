#!/bin/bash

# Manual OAuth2 with PKCE - No MCP server involved
# Just get an access token directly from NVIDIA SSO

CLIENT_ID="iPY1HAJZ3oFvPtLdJNeMrm1KB_M7YHRf_jbxi7WwbzM"
CLIENT_SECRET="sfcs-NgC4FbBgpPE4KWN8wu2qVAbKbKym9xx9"

echo "=========================================="
echo "Manual OAuth2 Authorization"
echo "=========================================="
echo ""

# Step 1: Generate PKCE
echo "Step 1: Generating PKCE values..."
CODE_VERIFIER=$(openssl rand -base64 32 | tr -d '=' | tr '+/' '-_')
CODE_CHALLENGE=$(echo -n "$CODE_VERIFIER" | openssl dgst -sha256 -binary | base64 | tr -d '=' | tr '+/' '-_')

echo "Code Verifier: $CODE_VERIFIER"
echo "$CODE_VERIFIER" > code_verifier.txt
echo ""

# Step 2: Show authorization URL
echo "Step 2: Open this URL in browser and login:"
echo "=========================================="
AUTH_URL="https://stg.login.nvidia.com/authorize?client_id=$CLIENT_ID&redirect_uri=https://talk-to-data-agent-service-dev.nvidia.com/auth/redirect&response_type=code&scope=openid%20profile%20email&state=manual123&code_challenge=$CODE_CHALLENGE&code_challenge_method=S256"
echo "$AUTH_URL"
echo "=========================================="
echo ""

# Try to open browser
open "$AUTH_URL" 2>/dev/null || xdg-open "$AUTH_URL" 2>/dev/null || echo "Copy URL above and open manually"

echo ""
echo "Step 3: After login, look at the URL in your browser"
echo "Even if you see an error page, the code is in the URL!"
echo ""
echo "The URL will look like:"
echo "https://...auth/redirect?code=LONG_CODE_HERE&state=manual123"
echo ""
echo "Copy JUST the code value (after 'code=' and before '&')"
echo ""
read -p "Paste the authorization code here: " CODE

if [ -z "$CODE" ]; then
    echo "❌ No code provided"
    exit 1
fi

echo ""
echo "Step 4: Exchanging code for access token..."
echo ""

# Exchange code for token
RESPONSE=$(curl -s -X POST https://stg.login.nvidia.com/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "code=$CODE" \
  -d "redirect_uri=https://talk-to-data-agent-service-dev.nvidia.com/auth/redirect" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "code_verifier=$CODE_VERIFIER")

# Check response
if echo "$RESPONSE" | grep -q "access_token"; then
    echo "✅ SUCCESS!"
    echo ""
    
    # Extract and save token
    ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    
    echo "Access Token (first 50 chars): ${ACCESS_TOKEN:0:50}..."
    echo ""
    
    # Save to file
    echo "$ACCESS_TOKEN" > access_token.txt
    echo "$RESPONSE" > token_full.json
    
    echo "✅ Token saved to: access_token.txt"
    echo "✅ Full response saved to: token_full.json"
    echo ""
    
    # Test the token
    echo "Step 5: Testing token..."
    echo ""
    
    USER_INFO=$(curl -s https://stg.login.nvidia.com/userinfo \
      -H "Authorization: Bearer $ACCESS_TOKEN")
    
    if echo "$USER_INFO" | grep -q "email"; then
        EMAIL=$(echo "$USER_INFO" | grep -o '"email":"[^"]*"' | cut -d'"' -f4)
        echo "✅ Token is valid!"
        echo "Authenticated as: $EMAIL"
        echo ""
        echo "User info:"
        echo "$USER_INFO" | python3 -m json.tool 2>/dev/null || echo "$USER_INFO"
    else
        echo "⚠️  Could not verify token"
        echo "$USER_INFO"
    fi
    
    echo ""
    echo "=========================================="
    echo "✅ All done!"
    echo "=========================================="
    echo ""
    echo "To use this token:"
    echo "  export ACCESS_TOKEN=\$(cat access_token.txt)"
    echo ""
    echo "Test with curl:"
    echo "  curl -H \"Authorization: Bearer \$ACCESS_TOKEN\" https://stg.login.nvidia.com/userinfo"
    
else
    echo "❌ Error getting token:"
    echo ""
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    echo ""
    echo "Common issues:"
    echo "  - Code expired (codes are valid for ~60 seconds)"
    echo "  - Code already used (each code can only be used once)"
    echo "  - Wrong code copied"
    echo ""
    echo "Try running the script again!"
fi
