# Dagger Engine Connectivity Analysis

## Problem Summary

### Issue Description
The Dagger build pipeline using `kube-pod://` runner connectivity fails during actual operations (core version, queries, function calls) while basic version commands succeed. This affects the verbose build script designed to replace Argo workflows.

### Root Cause Analysis

#### Security Context Mismatch
| Component | User | Security Context | Capabilities |
|-----------|------|------------------|-------------|
| **Workspace Pod** | `coder (1000)` | `runAsNonRoot: true`<br>`runAsUser: 1000`<br>`fsGroup: 1000` | **Restricted** |
| **Dagger Engine Pod** | `root (0)` | `privileged: true`<br>`capabilities: ALL`<br>`runAsUser: 0` | **ALL capabilities** |

#### Socket Permission Issue
```bash
# Dagger engine socket permissions:
srw-rw---- root:1001 /run/dagger/engine.sock
```

The workspace pod (user 1000) cannot properly communicate through the Unix socket owned by root:1001, causing:
- ✅ Version commands work (basic connectivity)
- ❌ Core operations timeout (socket communication fails)

#### Connection Flow Problem
```
Workspace Pod (unprivileged) → kube-pod:// → Dagger Engine Socket (privileged)
     ↓                              ↓                        ↓
User 1000:1000              kubectl exec              root:1001 socket
Restricted caps          Permission check         Requires privilege
```

## Current Status

### ✅ Working Components
- Dagger engine pods (7 running, healthy)
- Basic `dagger version` command
- Engine processes and readiness probes
- Unix socket exists at `/run/dagger/engine.sock`
- Admin kubeconfig access

### ❌ Failing Components
- `dagger core version` (timeouts)
- `dagger query` operations (timeouts)
- `dagger call` function calls (timeouts)
- Actual build pipeline execution

### 🔍 Key Findings
- **NOT an RBAC issue** - admin kubeconfig shows same behavior
- **NOT a dagger setup issue** - engine is correctly configured
- **Security context mismatch** between workspace and engine pods
- **Socket permission barriers** prevent proper communication

## Solutions

### 🚫 Not Recommended: Elevate Workspace Permissions
```yaml
# DON'T DO THIS - Security risk
securityContext:
  privileged: true
  runAsUser: 0
```
**Why not:** Violates security best practices, unnecessary privilege escalation.

### ✅ Recommended: TCP Connection Method

#### 1. Expose Dagger Engine via TCP Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: dagger-engine-tcp
  namespace: dagger
spec:
  selector:
    name: dagger-dagger-helm-engine
  ports:
  - port: 2345
    targetPort: 2345
    protocol: TCP
```

#### 2. Configure Engine for TCP
- Add TCP port to dagger engine configuration
- Enable TLS encryption in `buildkitd.toml`
- Configure proper authentication

#### 3. Update Connection String
```bash
# Replace this:
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="kube-pod://dagger?namespace=dagger&context=marieberg-context"

# With this:
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="tcp://dagger-engine-tcp.dagger.svc.cluster.local:2345"
```

### 🔧 Alternative: Port-Forward (Development Only)
```bash
kubectl port-forward -n dagger svc/dagger-engine-tcp 2345:2345 &
export _EXPERIMENTAL_DAGGER_RUNNER_HOST="tcp://localhost:2345"
```

## Important Considerations

### ⚠️ Load Balancing Issue
- Dagger opens **4 connections** to the engine
- Kubernetes services use **round-robin** load balancing
- Multiple engine pods cause **session conflicts**

### 💡 Solution: Single Engine Instance
1. **Change DaemonSet to Deployment** (single pod)
2. **Use session-aware load balancing** if multiple replicas needed
3. **Consider engine affinity** for consistent routing

### 🔒 Security Requirements
- **TLS encryption** for TCP connections
- **Proper authentication** configuration
- **Network policies** to restrict access
- **Regular security audits** of engine exposure

## Implementation Steps

1. **Create TCP Service** for dagger engine
2. **Configure TLS encryption** in engine
3. **Update build scripts** to use TCP connection
4. **Test connectivity** from workspace pod
5. **Implement monitoring** for TCP connections
6. **Document security configurations**

## Benefits of TCP Approach

- ✅ **No elevated permissions** required in workspace
- ✅ **Proper encryption** over the wire
- ✅ **Better security model** than Unix sockets
- ✅ **Avoids session conflicts** with proper configuration
- ✅ **More flexible deployment** options
- ✅ **Easier troubleshooting** and monitoring

## Files Modified

- `/home/coder/coder-templates/Riksarkivets-Development-Template/build-dagger.sh`
  - Updated to use correct kubeconfig
  - Fixed context name from `default` to `marieberg-context`
  - Ready for TCP connection string update

## Next Steps

1. Implement TCP service configuration
2. Test TCP connectivity from workspace
3. Update build pipeline to use TCP connection
4. Validate end-to-end build process
5. Document deployment procedures

---

**Status:** Ready to implement TCP solution
**Priority:** High - Required for build pipeline functionality
**Security:** Maintains security best practices while enabling functionality