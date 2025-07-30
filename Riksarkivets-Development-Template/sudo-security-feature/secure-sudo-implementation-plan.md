# Secure Sudo Implementation Plan

## Phase 1: Immediate Security Fix (High Priority)

### 1.1 Update Dockerfile
Replace the insecure sudo configuration:
```dockerfile
# REMOVE (lines 26-27):
echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd && \
chmod 440 /etc/sudoers.d/nopasswd && \

# ADD: Secure configuration + scripts
COPY request-sudo-access.sh /usr/local/bin/request-sudo-access
RUN chmod +x /usr/local/bin/request-sudo-access && \
    apt-get update && apt-get install -y --no-install-recommends at && \
    cat > /etc/sudoers.d/coder-restricted << 'EOF' && \
# Secure sudo configuration for ML development workspace
coder ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/apt, /usr/bin/dpkg
coder ALL=(ALL) NOPASSWD: /usr/bin/pip, /usr/bin/pip3, /usr/local/bin/uv  
coder ALL=(ALL) NOPASSWD: /home/linuxbrew/.linuxbrew/bin/brew
coder ALL=(ALL) NOPASSWD: /usr/bin/nvidia-smi
coder ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/chown, /bin/chmod
EOF
    chmod 440 /etc/sudoers.d/coder-restricted && \
    echo 'alias sudo-help="request-sudo-access"' >> /home/coder/.bashrc && \
    rm -rf /var/lib/apt/lists/*
```

### 1.2 Required Files to Add
- `request-sudo-access.sh` - Main temporary access script
- `admin-override.md` - Documentation for administrators  
- `sudo-access-examples.md` - User documentation

### 1.3 Build and Test
```bash
# Build new secure image
make build

# Test in development workspace
docker run -it <image> bash
sudo-help docker 1h
sudo docker ps  # Should work after granting access
```

## Phase 2: Enhanced Features (Medium Priority)

### 2.1 Add Terraform Variables
```hcl
variable "sudo_access_level" {
  description = "Default sudo access level"
  type        = string
  default     = "restricted"
  validation {
    condition = contains(["none", "restricted", "development"], var.sudo_access_level)
    error_message = "Must be: none, restricted, or development"
  }
}
```

### 2.2 Add Workspace Parameters
Allow users to choose sudo level at workspace creation:
- **None** - No sudo access (maximum security)
- **Restricted** - Package management only (default)
- **Development** - Extended permissions for development tasks

### 2.3 Logging and Monitoring
```dockerfile
# Add sudo logging configuration
RUN echo "Defaults logfile=/var/log/sudo.log" >> /etc/sudoers.d/coder-restricted && \
    echo "Defaults log_input, log_output" >> /etc/sudoers.d/coder-restricted
```

## Phase 3: Advanced Security (Low Priority)

### 3.1 RBAC Integration
- Integrate with Kubernetes RBAC for cluster-level permissions
- Service account-based access control
- Namespace-specific permission boundaries

### 3.2 Audit Dashboard
- Centralized logging of all sudo usage
- Real-time monitoring of privilege escalations
- Automated alerts for suspicious activity

### 3.3 Policy Engine
- Configurable sudo policies per team/project
- Approval workflows for high-privilege requests
- Integration with identity providers

## Implementation Checklist

### ✅ Files to Create/Modify:
- [ ] `request-sudo-access.sh` - ✅ Created
- [ ] `admin-override.md` - ✅ Created  
- [ ] `sudo-access-examples.md` - ✅ Created
- [ ] `Dockerfile` - Update sudo configuration
- [ ] Update issues.md - Mark issue #5 as resolved
- [ ] Update README.md - Document new security model

### ✅ Testing Requirements:
- [ ] Test restricted sudo works for package management
- [ ] Test temporary access script grants correct permissions
- [ ] Test automatic cleanup after expiration
- [ ] Test all permission types (docker, services, network, etc.)
- [ ] Verify security - ensure dangerous commands still blocked

### ✅ Documentation Updates:
- [ ] User guide for requesting additional permissions
- [ ] Administrator guide for emergency overrides
- [ ] Security model documentation
- [ ] Troubleshooting guide for permission issues

## Security Benefits Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Default Access** | Full root (CRITICAL) | Package management only (LOW) |
| **Additional Access** | Always available | Temporary, self-service |
| **Audit Trail** | None | Full logging with timestamps |
| **Attack Surface** | Unlimited | Minimal, task-specific |
| **Compliance** | Fails most security audits | Passes security reviews |
| **User Experience** | Full access always | Secure by default, flexible when needed |

## Rollback Plan

If issues arise, emergency rollback:
```dockerfile
# Temporary rollback to full access (emergency only)
echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/emergency
```

Remove when resolved:
```bash
sudo rm -f /etc/sudoers.d/emergency
```