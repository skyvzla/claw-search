#!/bin/bash
# Deploy script for claw-search with SearXNG
# NOTE: This script requires sudo for Docker commands
# This script sets up everything needed for claw-search to work

set -e

echo "🚀 claw-search Deployment Script"
echo "================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if SearXNG is already running
if sudo docker ps | grep -q searxng; then
    echo -e "${GREEN}✅ SearXNG is already running${NC}"
else
    echo "📦 Step 1: Deploying SearXNG..."
    
    # Check if `./searxng/settings.yml` exists; if not, copy it.
    if [ ! -f "./searxng/settings.yml" ]; then
        sudo docker run -d \
            --name searxng \
            --restart=always \
            searxng/searxng:latest
        
        echo "   Waiting for initialization (20 seconds)..."
        sleep 20

        # Enable JSON API (critical step!)
        echo "   Enabling JSON API..."
        sudo docker exec searxng sed -i '/^  formats:$/a\    - json' /etc/searxng/settings.yml
        
        # Enable Chinese search engines for better Chinese content
        echo "   Enabling Chinese search engines (baidu, sogou, bing, chinaso news, bilibili, iqiyi)..."
        sudo docker exec searxng sed -i '/^  - name: baidu$/,/^    disabled:/ s/disabled: true/disabled: false/' /etc/searxng/settings.yml
        sudo docker exec searxng sed -i '/^  - name: sogou$/,/^    disabled:/ s/disabled: true/disabled: false/' /etc/searxng/settings.yml
        sudo docker exec searxng sed -i '/^  - name: bing$/,/^    disabled:/ s/disabled: true/disabled: false/' /etc/searxng/settings.yml
        sudo docker exec searxng sed -i '/^  - name: chinaso news$/,/^    disabled:/ s/disabled: true/disabled: false/' /etc/searxng/settings.yml
        sudo docker exec searxng sed -i '/^  - name: chinaso news$/,/^    inactive:/ s/inactive: true/inactive: false/' /etc/searxng/settings.yml
        sudo docker exec searxng sed -i '/^  - name: bilibili$/,/^    disabled:/ s/disabled: true/disabled: false/' /etc/searxng/settings.yml
        sudo docker exec searxng sed -i '/^  - name: iqiyi$/,/^    disabled:/ s/disabled: true/disabled: false/' /etc/searxng/settings.yml

        mkdir -p ./searxng
        echo "   Copy configuration file..."
        docker cp searxng:/etc/searxng/settings.yml ./searxng/settings.yml
    fi

    # Clean up old containers/volumes
    sudo docker stop searxng 2>/dev/null || true
    sudo docker rm searxng 2>/dev/null || true
    
    # Start SearXNG with default config
    sudo docker run -d \
      --name searxng \
      --restart=always \
      -p 8888:8080 \
      -v ./searxng/settings.yml:/etc/searxng/settings.yml \
      searxng/searxng:latest
    
    echo -e "${GREEN}✅ SearXNG container started${NC}"
    echo "   Waiting for initialization (20 seconds)..."
    sleep 20
    
    echo -e "${GREEN}✅ SearXNG configured with JSON API and Chinese engines${NC}"
fi

# Verify SearXNG is working
echo ""
echo "📦 Step 2: Verifying SearXNG..."
if curl -s --max-time 5 "http://localhost:8888" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ SearXNG is accessible at http://localhost:8888${NC}"
    
    # Test JSON API
    RESULT_COUNT=$(curl -s "http://localhost:8888/search?q=test&format=json" 2>/dev/null | jq -r '.results | length' 2>/dev/null || echo "0")
    if [ "$RESULT_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ JSON API is working ($RESULT_COUNT results)${NC}"
    else
        echo -e "${YELLOW}⚠️  JSON API not ready, but continuing...${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  SearXNG may still be starting${NC}"
fi

# Install plugin
echo ""
echo "📦 Step 3: Installing claw-search plugin..."
openclaw plugins install .

# Configure plugins.allow (OpenClaw 2026.2.19+)
[ -f ~/.openclaw/openclaw.json ] && command -v jq &>/dev/null && \
jq '.plugins.allow=(.plugins.allow//[]|.+["claw-search"]|unique)' ~/.openclaw/openclaw.json > /tmp/oc.tmp && mv /tmp/oc.tmp ~/.openclaw/openclaw.json

echo -e "${GREEN}✅ Plugin installed${NC}"

# Restart gateway
echo ""
echo "📦 Step 4: Restarting OpenClaw gateway..."
openclaw gateway restart

echo ""
echo "================================="
echo -e "${GREEN}✨ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Wait 10 seconds for gateway to fully restart"
echo "  2. Run: ./test.sh"
echo "  3. Or ask OpenClaw: 'Search for Python tutorials'"
echo ""
echo "URLs:"
echo "  SearXNG: http://localhost:8888"
echo "  Plugin: ~/.openclaw/extensions/claw-search"
echo ""
echo -e "${BLUE}Tip:${NC} If tests fail, wait a bit longer and try again."
echo "     SearXNG needs ~30 seconds for full initialization."
