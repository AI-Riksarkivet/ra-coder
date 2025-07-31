#!/bin/bash

# VS Code Sites Connectivity Checker
# Checks if VS Code related domains are accessible

echo "VS Code Sites Connectivity Check"
echo "================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check site accessibility
check_site() {
    local url=$1
    local description=$2
    
    printf "%-50s " "$description"
    
    # Try HTTPS first, then HTTP if needed
    local http_code
    http_code=$(curl -s --connect-timeout 10 --max-time 15 -o /dev/null -w "%{http_code}" "https://$url" 2>/dev/null)
    
    if [[ "$http_code" =~ ^(200|301|302|403|404)$ ]]; then
        echo -e "${GREEN}✓ Accessible (HTTP $http_code)${NC}"
        return 0
    else
        # Try with HTTP if HTTPS fails
        http_code=$(curl -s --connect-timeout 10 --max-time 15 -o /dev/null -w "%{http_code}" "http://$url" 2>/dev/null)
        if [[ "$http_code" =~ ^(200|301|302|403|404)$ ]]; then
            echo -e "${YELLOW}✓ Accessible via HTTP only (HTTP $http_code)${NC}"
            return 0
        else
            echo -e "${RED}✗ Not accessible${NC}"
            return 1
        fi
    fi
}

# Function to check DNS resolution
check_dns() {
    local url=$1
    local description=$2
    
    printf "%-50s " "$description (DNS)"
    
    if nslookup "$url" >/dev/null 2>&1 || dig "$url" >/dev/null 2>&1 || host "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Resolved${NC}"
        return 0
    else
        echo -e "${RED}✗ DNS failed${NC}"
        return 1
    fi
}

# Core VS Code sites
declare -a core_sites=(
    "update.code.visualstudio.com|VS Code update server"
    "code.visualstudio.com|VS Code main site"
    "marketplace.visualstudio.com|VS Code Marketplace"
    "vscode.dev|VS Code for the Web"
    "download.visualstudio.microsoft.com|VS Code downloads"
)

# Extension and asset sites
declare -a extension_sites=(
    "az764295.vo.msecnd.net|Gallery assets CDN"
    "vsmarketplacebadge.azureedge.net|Marketplace badges CDN"
    "vsmarketplacebadges.dev|Marketplace badges service"
    "unpkg.com|Package CDN for web extensions"
    "cdn.jsdelivr.net|Alternative package CDN"
)

# Microsoft services
declare -a microsoft_sites=(
    "go.microsoft.com|Microsoft redirects"
    "login.microsoftonline.com|Microsoft authentication"
    "graph.microsoft.com|Microsoft Graph API"
    "vscode-sync.trafficmanager.net|Settings Sync service"
    "vscode-auth.github.com|GitHub authentication"
)

# Telemetry and analytics
declare -a telemetry_sites=(
    "dc.applicationinsights.microsoft.com|Application Insights"
    "dc.applicationinsights.azure.com|Azure Application Insights"
    "vortex.data.microsoft.com|Telemetry service"
    "default.exp-tas.com|A/B testing service"
)

# Third-party services
declare -a third_party_sites=(
    "raw.githubusercontent.com|GitHub raw content"
    "api.github.com|GitHub API"
    "github.com|GitHub main site"
    "registry.npmjs.org|NPM registry"
)

# Go module sites
declare -a go_sites=(
    "proxy.golang.org|Go module proxy"
    "sum.golang.org|Go checksum database"
    "index.golang.org|Go module index"
    "go.googlesource.com|Go source repositories"
    "gitlab.com|GitLab repositories"
    "bitbucket.org|Bitbucket repositories"
)

echo -e "${BLUE}Checking core VS Code functionality...${NC}"
accessible_count=0
total_count=0

for site_info in "${core_sites[@]}"; do
    IFS='|' read -r url description <<< "$site_info"
    if check_site "$url" "$description"; then
        ((accessible_count++))
    fi
    ((total_count++))
done

echo ""
echo -e "${BLUE}Checking extension marketplace...${NC}"
for site_info in "${extension_sites[@]}"; do
    IFS='|' read -r url description <<< "$site_info"
    if check_site "$url" "$description"; then
        ((accessible_count++))
    fi
    ((total_count++))
done

echo ""
echo -e "${BLUE}Checking Microsoft services...${NC}"
for site_info in "${microsoft_sites[@]}"; do
    IFS='|' read -r url description <<< "$site_info"
    if check_site "$url" "$description"; then
        ((accessible_count++))
    fi
    ((total_count++))
done

echo ""
echo -e "${BLUE}Checking telemetry services...${NC}"
for site_info in "${telemetry_sites[@]}"; do
    IFS='|' read -r url description <<< "$site_info"
    if check_site "$url" "$description"; then
        ((accessible_count++))
    fi
    ((total_count++))
done

echo ""
echo -e "${BLUE}Checking third-party services...${NC}"
for site_info in "${third_party_sites[@]}"; do
    IFS='|' read -r url description <<< "$site_info"
    if check_site "$url" "$description"; then
        ((accessible_count++))
    fi
    ((total_count++))
done

echo ""
echo -e "${BLUE}Checking Go module sites...${NC}"
for site_info in "${go_sites[@]}"; do
    IFS='|' read -r url description <<< "$site_info"
    if check_site "$url" "$description"; then
        ((accessible_count++))
    fi
    ((total_count++))
done

echo ""
echo "================================="
echo -e "Summary: ${GREEN}$accessible_count${NC}/${total_count} sites accessible"

# Provide recommendations based on results
echo ""
echo -e "${BLUE}Recommendations:${NC}"

if [ $accessible_count -eq $total_count ]; then
    echo -e "${GREEN}✓ All VS Code sites are accessible!${NC}"
    echo "  VS Code should work normally without any connectivity issues."
    exit 0
elif [ $accessible_count -gt $((total_count * 3 / 4)) ]; then
    echo -e "${YELLOW}⚠ Most sites accessible, minor functionality may be limited.${NC}"
    echo "  Core VS Code features should work, but some extensions or services may be affected."
    exit 0
elif [ $accessible_count -gt $((total_count / 2)) ]; then
    echo -e "${YELLOW}⚠ Some connectivity issues detected.${NC}"
    echo "  VS Code will work but with limited functionality:"
    echo "  - Extension marketplace may be slow or unavailable"
    echo "  - Settings sync may not work"
    echo "  - Some authentication features may fail"
    echo "  - Go module downloads may fail"
    echo ""
    echo "  Consider configuring proxy settings or firewall exceptions."
    exit 1
elif [ $accessible_count -gt 0 ]; then
    echo -e "${RED}⚠ Significant connectivity issues.${NC}"
    echo "  VS Code may have severe limitations:"
    echo "  - Extensions may not install or update"
    echo "  - Authentication will likely fail"
    echo "  - Updates may not work"
    echo "  - Go development will be severely limited"
    echo ""
    echo "  Contact your network administrator to allow VS Code domains."
    exit 1
else
    echo -e "${RED}✗ No VS Code sites accessible.${NC}"
    echo "  VS Code will have very limited functionality:"
    echo "  - No extension marketplace access"
    echo "  - No updates or authentication"
    echo "  - Only offline features will work"
    echo ""
    echo "  Check internet connection or proxy configuration."
    exit 2
fi