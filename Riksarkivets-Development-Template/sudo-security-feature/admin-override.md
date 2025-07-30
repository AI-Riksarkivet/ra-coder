# Administrative Override Procedures

## When Users Need Additional Access

### Option 1: Workspace Restart with Different Configuration
```bash
# Admin can update the workspace with higher sudo level
terraform apply -var="sudo_access_level=development"
```

### Option 2: Temporary Access Script
Users can run the self-service script:
```bash
./request-sudo-access.sh docker 2h     # Docker access for 2 hours
./request-sudo-access.sh services 30m  # Service management for 30 minutes
```

### Option 3: Emergency Admin Access (Break Glass)
For critical situations, administrators can temporarily restore full access:

```bash
# Emergency procedure (requires admin access to cluster)
kubectl exec -it <workspace-pod> -- \
  sudo bash -c 'echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/emergency'

# Remember to remove after use:
kubectl exec -it <workspace-pod> -- \
  sudo rm -f /etc/sudoers.d/emergency
```

### Option 4: Custom Image Build
For persistent needs, build a custom image:
```bash
# Build with development sudo level
make build SUDO_LEVEL=development

# Or build with specific additional tools
docker build --build-arg EXTRA_TOOLS="docker,kubectl" .
```

## Access Level Definitions

### Restricted (Default - Production Safe)
- Package management only
- GPU monitoring
- Basic file operations

### Development (Extended for Development)
- All restricted permissions
- Docker daemon access
- Service management
- Network tools
- kubectl operations

### Admin (Full Access - Use Sparingly)
- Unrestricted sudo access
- Should be temporary only
- Requires justification and approval

## Audit and Logging

All sudo usage is logged to:
- `/var/log/sudo.log` (if configured)
- System journal: `journalctl -u sudo`
- Container logs in Kubernetes

## Security Guidelines

1. **Default to Restricted** - Use minimal permissions by default
2. **Time-Limited Access** - Grant additional permissions temporarily
3. **Audit Trail** - Log all privilege escalations  
4. **Least Privilege** - Grant only the minimum required access
5. **Regular Review** - Periodically review and revoke unnecessary permissions