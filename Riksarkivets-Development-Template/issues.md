# Outstanding Issues in ML Workspace Template

## Security Issues

### 5. Container Runs with Full Sudo Access (Dockerfile:24) - 🔧 SOLUTION READY
**File:** `Dockerfile`  
**Line:** 24  
**Issue:** `echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd`  
**Impact:** Container user has unrestricted sudo access without password.  
**Severity:** High  
**Solution:** Complete secure sudo implementation available in `sudo-security-feature/` folder:
- **Kaniko-compatible inline script embedding** (recommended for current build system)
- **Self-service temporary access system** for additional permissions when needed
- **Granular permissions** for package management, GPU monitoring, file operations only
- **Automatic cleanup** of temporary elevated permissions
- **Full audit trail** of all sudo usage
**Implementation:** See `sudo-security-feature/README.md` for deployment options
**Files:** `sudo-security-feature/dockerfile-inline-scripts.patch` (ready to apply)

### 6. Insecure Registry Configuration (build.yaml:40-41)
**File:** `build.yaml`  
**Lines:** 40-41  
**Issue:** Kaniko configured with `--insecure` and `--insecure-registry` flags.  
**Impact:** Disables TLS verification for registry communication.  
**Fix:** Use proper TLS certificates for registry or limit insecure access.

### 7. Missing Secret Validation
**File:** `main.tf`  
**Lines:** 311-313  
**Issue:** No validation that LakeFS secrets exist before reading them.
```bash
LAKECTL_ACCESS_KEY_ID=$(cat /etc/secrets/lakefs/access_key_id)
LAKECTL_SECRET_ACCESS_KEY=$(cat /etc/secrets/lakefs/secret_access_key)
```
**Impact:** Startup script fails if secrets are missing.  
**Fix:** Add error handling and validation for secret files.

## Configuration Issues

### 8. No Resource Quotas or Limits Validation
**File:** `main.tf`  
**Issue:** CPU/memory parameter validation allows unrealistic values (96GB RAM, 24 cores).  
**Impact:** Users could request more resources than available on nodes.  
**Fix:** Add realistic validation ranges based on cluster capacity.

### 9. Missing Namespace Validation
**File:** `main.tf`  
**Line:** 32  
**Issue:** Namespace variable has no default value and no validation.  
**Impact:** Deployment fails if namespace doesn't exist.  
**Fix:** Add validation or provide sensible default.

### 10. Incomplete Error Handling in Startup Script
**File:** `main.tf`  
**Lines:** 367-377  
**Issue:** Git configuration errors are logged but don't fail the startup script.  
**Impact:** Silent failures in workspace setup.  
**Fix:** Improve error handling and make critical failures exit with error codes.

## Infrastructure Issues

### 11. HostPath Security Risk (main.tf:771-783)
**File:** `main.tf`  
**Lines:** 771-783  
**Issue:** Direct host path mounts to `/mnt/scratch` and `/mnt/work`.  
**Impact:** Workspaces can access/modify host filesystem locations.  
**Fix:** Use PVCs instead of host paths or restrict with security policies.

### 12. Missing Backup Strategy
**Issue:** No backup configuration for persistent volumes.  
**Impact:** Data loss risk for user home directories.  
**Fix:** Implement PVC backup/snapshot policies.

### 13. No Resource Monitoring
**Issue:** While metadata collection exists, no alerting or automated resource management.  
**Impact:** No early warning for resource exhaustion.  
**Fix:** Add resource monitoring and alerting configuration.

## Documentation Issues

### 14. Outdated Documentation
**File:** `README.md`  
**Issue:** Documentation references old image versions and missing features.  
**Impact:** Users follow incorrect setup instructions.  
**Fix:** Update documentation to match current implementation.

### 15. Missing Troubleshooting Guide
**Issue:** No troubleshooting documentation for common issues.  
**Impact:** Users can't resolve common problems independently.  
**Fix:** Add troubleshooting section to documentation.

## Build System Issues

### 16. Build Script Lacks Error Handling
**File:** `build.sh`  
**Issue:** Script doesn't validate argo CLI availability or handle workflow submission failures properly.  
**Impact:** Build failures may not be properly reported.  
**Fix:** Add comprehensive error handling and validation.

### 17. No Build Artifacts Cleanup
**Issue:** Argo workflows set to auto-delete after 3 hours but no cleanup for failed builds.  
**Impact:** Accumulation of failed workflow resources.  
**Fix:** Implement proper cleanup policies for all workflow states.

## Performance Issues

### 18. Large Base Image
**File:** `Dockerfile`  
**Issue:** Installing many tools in single layer creates large image.  
**Impact:** Slow container startup and network transfer.  
**Fix:** Optimize Dockerfile with multi-stage builds and layer caching.

### 19. No Caching Strategy
**Issue:** No explicit caching configuration for Homebrew, pip, or other package managers.  
**Impact:** Slow builds and workspace startup times.  
**Fix:** Add proper caching layers in Dockerfile.

## ML-Specific Issues

### 20. No GPU Utilization Monitoring
**Issue:** GPU resources requested but no monitoring of actual utilization.  
**Impact:** GPU resource waste and no visibility into usage patterns.  
**Fix:** Add GPU monitoring to metadata collection.

### 21. No Model Storage Integration
**Issue:** No integration with model storage solutions beyond basic LakeFS configuration.  
**Impact:** Users must manually configure model registries and storage.  
**Fix:** Add integration with common ML model storage solutions.

### 22. Limited ML Framework Coverage
**Issue:** Only PyTorch is pre-installed, missing other popular frameworks.  
**Impact:** Users working with TensorFlow, JAX, or other frameworks need manual setup.  
**Fix:** Add support for multiple ML frameworks or easy switching mechanism.

---

## Recently Resolved Issues

For reference, the following issues have been resolved:

- **Issue #1:** Docker Volume Mount Not Used - ✅ FIXED
- **Issue #2:** Image Version Inconsistencies - ✅ FIXED  
- **Issue #3:** Python Package Management Clarity - ✅ RESOLVED
- **Issue #4:** Hardcoded Registry URLs - ✅ FIXED
- **Issue #23:** Missing RBAC Permissions for Argo Workflows - ✅ FIXED

## Issue Summary

**Total Outstanding Issues:** 18  
**Security Issues:** 3 🔴  
**Configuration Issues:** 3 🟡  
**Infrastructure Issues:** 3 🟡  
**Documentation Issues:** 2 🟡  
**Build System Issues:** 2 🟡  
**Performance Issues:** 2 🟡  
**ML-Specific Issues:** 3 🟡  

**Priority Breakdown:**
- **High Priority (Security):** Issues 5, 6, 7, 11
- **Medium Priority (Functionality):** Issues 8, 9, 10, 16, 20, 21, 22
- **Low Priority (Quality of Life):** Issues 12, 13, 14, 15, 17, 18, 19