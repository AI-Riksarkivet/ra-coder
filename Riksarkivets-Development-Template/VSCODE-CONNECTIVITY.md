# VS Code Connectivity Checker

This script checks connectivity to VS Code-related domains to help diagnose firewall or network issues that might affect VS Code functionality.

## Usage

```bash
./check-vscode-connectivity.sh
```

## What it checks

The script tests connectivity to several categories of sites:

### Core VS Code functionality
- `update.code.visualstudio.com` - VS Code update server
- `code.visualstudio.com` - VS Code main site
- `marketplace.visualstudio.com` - VS Code Marketplace
- `vscode.dev` - VS Code for the Web
- `download.visualstudio.microsoft.com` - VS Code downloads

### Extension marketplace
- `az764295.vo.msecnd.net` - Gallery assets CDN
- `vsmarketplacebadge.azureedge.net` - Marketplace badges CDN
- `vsmarketplacebadges.dev` - Marketplace badges service
- `unpkg.com` - Package CDN for web extensions
- `cdn.jsdelivr.net` - Alternative package CDN

### Microsoft services
- `go.microsoft.com` - Microsoft redirects
- `login.microsoftonline.com` - Microsoft authentication
- `graph.microsoft.com` - Microsoft Graph API
- `vscode-sync.trafficmanager.net` - Settings Sync service
- `vscode-auth.github.com` - GitHub authentication

### Telemetry and analytics
- `dc.applicationinsights.microsoft.com` - Application Insights
- `dc.applicationinsights.azure.com` - Azure Application Insights
- `vortex.data.microsoft.com` - Telemetry service
- `default.exp-tas.com` - A/B testing service

### Third-party services
- `raw.githubusercontent.com` - GitHub raw content
- `api.github.com` - GitHub API
- `github.com` - GitHub main site
- `registry.npmjs.org` - NPM registry

## Exit codes

- `0` - All sites accessible or minor issues
- `1` - Some connectivity issues that may limit functionality
- `2` - Severe connectivity issues

## Interpreting results

### ✓ All accessible
VS Code should work normally without any connectivity issues.

### ⚠ Most sites accessible
Core VS Code features should work, but some extensions or services may be affected.

### ⚠ Some connectivity issues
VS Code will work but with limited functionality:
- Extension marketplace may be slow or unavailable
- Settings sync may not work
- Some authentication features may fail

### ⚠ Significant connectivity issues
VS Code may have severe limitations:
- Extensions may not install or update
- Authentication will likely fail
- Updates may not work

### ✗ No sites accessible
VS Code will have very limited functionality:
- No extension marketplace access
- No updates or authentication
- Only offline features will work

## Firewall configuration

If you're behind a corporate firewall, you may need to allowlist these domains. Common approaches:

1. **Proxy configuration**: Configure VS Code to use your corporate proxy
2. **Firewall exceptions**: Ask your network administrator to allow these domains
3. **Alternative CDNs**: Some content may be available through alternative CDNs

## Troubleshooting

1. **Check proxy settings**: Ensure curl can access the internet through your proxy
2. **DNS resolution**: The script will indicate if DNS resolution is failing
3. **Certificate issues**: Some corporate firewalls inspect HTTPS traffic
4. **Rate limiting**: Some services may rate limit requests

## VS Code proxy configuration

If you need to configure VS Code to work with a proxy, add these settings to your VS Code configuration:

```json
{
  "http.proxy": "http://proxy.company.com:8080",
  "http.proxyStrictSSL": false,
  "http.proxySupport": "on"
}
```