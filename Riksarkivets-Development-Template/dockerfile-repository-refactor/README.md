# Dockerfile Repository Refactor

This folder contains the action plan and implementation files for refactoring the build system to pull the Dockerfile directly from the Git repository instead of passing it as a parameter.

## 🎯 **Current Problem**

The build system currently passes the entire Dockerfile content as a parameter:
```bash
# In build.sh
-p dockerfileContent="$(cat Dockerfile)"
```

This approach has several issues:
- **Parameter size limits** - Large Dockerfiles may exceed parameter limits
- **No version control** - Parameter content isn't tied to a specific Git commit
- **Security concerns** - Dockerfile content passed through workflow parameters
- **Debugging difficulty** - Hard to trace which Dockerfile version was used
- **Workflow complexity** - Large parameters make workflows harder to read

## ✅ **Proposed Solution**

Pull the Dockerfile directly from the Git repository within the Kaniko build:

```yaml
# New approach - Git repository as source
- name: git-source
  git:
    repo: "{{workflow.parameters.gitRepo}}"
    revision: "{{workflow.parameters.gitRevision}}"
```

## 📁 **Files in this Feature**

### Implementation Plans
- **`action-plan.md`** - Detailed implementation roadmap
- **`technical-analysis.md`** - Technical considerations and trade-offs
- **`migration-strategy.md`** - Safe migration approach

### Implementation Files (To Be Created)
- **`build-v2.yaml`** - New build workflow with Git source
- **`build-v2.sh`** - Updated build script
- **`dockerfile-context-analysis.md`** - Analysis of Dockerfile context requirements

### Testing and Validation
- **`testing-plan.md`** - Comprehensive testing strategy
- **`rollback-procedure.md`** - Safe rollback if issues arise

## 🔄 **Migration Phases**

### Phase 1: Analysis and Planning
- Analyze current Dockerfile and build context requirements
- Design new Git-based workflow
- Create implementation files

### Phase 2: Implementation
- Create new build workflow (build-v2.yaml)
- Update build scripts
- Add Git repository parameters

### Phase 3: Testing
- Test with development builds
- Validate build context handling
- Performance comparison

### Phase 4: Migration
- Gradual rollout with fallback option
- Update documentation
- Remove old parameter-based approach

## 🎯 **Expected Benefits**

### ✅ **Technical Benefits**
- **True version control** - Builds tied to specific Git commits
- **Reduced parameter complexity** - No large Dockerfile content in parameters
- **Better debugging** - Clear traceability of source code used
- **Improved security** - No sensitive content in workflow parameters
- **Standard practices** - Aligns with typical CI/CD patterns

### ✅ **Operational Benefits**
- **Easier troubleshooting** - Can examine exact source used for build
- **Better audit trail** - Git commit hash recorded in build logs
- **Simplified workflows** - Cleaner parameter structure
- **Scalability** - No parameter size limitations

## ⚠️ **Considerations**

### 🔍 **Technical Challenges**
- **Git authentication** - Need proper credentials for private repos
- **Build context** - Ensure all Dockerfile dependencies are available
- **Performance** - Git clone might add build time
- **Network dependencies** - Requires Git repository access during build

### 🛡️ **Risk Mitigation**
- **Dual approach** - Keep both methods during transition
- **Comprehensive testing** - Validate all build scenarios
- **Rollback plan** - Quick revert to current method if needed
- **Performance monitoring** - Measure impact on build times

## 🚀 **Implementation Options**

### Option 1: Pure Dagger with Kubernetes Engine (🌟🌟 HIGHLY RECOMMENDED)
- **Revolutionary approach**: Direct pipeline execution from workspace
- **Zero Argo complexity**: One Helm chart replaces entire CI/CD setup
- **Developer experience**: Interactive builds with real-time feedback
- **Shared infrastructure**: One engine serves multiple developers
- **See:** `dagger-implementation.md` for comprehensive analysis

### Option 2: Kaniko Git Context (Traditional)
- Direct Git integration with existing Kaniko setup
- Good performance, some authentication complexity
- **See:** `technical-analysis.md` for detailed implementation

### Option 3: Dagger + Argo Hybrid (Traditional CI/CD)
- Modern programmable CI/CD with workflow orchestration
- Better than pure Argo but more complex than pure Dagger
- **See:** `dagger-implementation.md` for implementation details

### Option 4: Gradual Migration
- Feature-flag based transition between approaches
- Support multiple methods during transition period
- **See:** `migration-strategy.md` for safe rollout plan

## 🚀 **Getting Started**

### 🌟 **Quick Start: Pure Dagger Approach (RECOMMENDED)**
1. **Deploy Dagger engine** - `helm install dagger oci://registry.dagger.io/dagger-helm -n dagger --create-namespace`
2. **Connect from workspace** - Set `_EXPERIMENTAL_DAGGER_RUNNER_HOST` environment variable
3. **Run builds directly** - `dagger call build-image --repo=... --tag=...`
4. **Replace complex CI/CD** - Direct execution instead of Argo workflows

### 📚 **Detailed Implementation Guides**
1. **For Pure Dagger** - Read `dagger-implementation.md` (🌟 recommended)
2. **For traditional Kaniko** - Follow `action-plan.md` and `technical-analysis.md`
3. **For Dagger + Argo hybrid** - See hybrid section in `dagger-implementation.md`
4. **For safe migration** - Use `migration-strategy.md` rollout plan
5. **For testing validation** - Use `testing-plan.md` for comprehensive testing

## 📊 **Success Metrics**

### Pure Dagger Approach
- ✅ **Direct workspace execution** - Developers can run builds interactively
- ✅ **Simplified infrastructure** - One Helm chart replaces complex CI/CD
- ✅ **Real-time feedback** - Immediate build results and error messages
- ✅ **Shared engine efficiency** - Multiple users leverage same resources
- ✅ **Git repository source** - No parameter size limitations
- ✅ **Performance improvement** - Persistent cache and optimized execution

### Traditional Approaches
- ✅ Builds work with Git repository source
- ✅ Build times remain acceptable (< 20% increase)
- ✅ All build contexts and dependencies work correctly
- ✅ Proper Git commit traceability in build logs
- ✅ No parameter size or complexity issues
- ✅ Easy rollback capability maintained