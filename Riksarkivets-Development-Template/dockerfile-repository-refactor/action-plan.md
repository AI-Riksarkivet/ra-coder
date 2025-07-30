# Dockerfile Repository Refactor - Action Plan

## 🎯 **Objective**
Refactor the Kaniko build system to pull Dockerfile and build context directly from Git repository instead of passing Dockerfile content as a parameter.

## 📋 **Phase 1: Analysis and Requirements (1-2 hours)**

### 1.1 Current System Analysis
- [ ] **Map current parameter flow** - Document how `dockerfileContent` flows through the system
- [ ] **Analyze build context** - Identify all files/directories the Dockerfile depends on
- [ ] **Review Kaniko capabilities** - Research Git source support in Kaniko
- [ ] **Check authentication** - Determine Git authentication requirements

### 1.2 Technical Requirements Gathering
- [ ] **Git repository URL** - Identify the exact repo URL to use
- [ ] **Branch/tag strategy** - Determine how to specify Git revision
- [ ] **Build context scope** - Define what files need to be available
- [ ] **Authentication method** - Choose between SSH keys, tokens, or service accounts

### 1.3 Risk Assessment
- [ ] **Identify breaking changes** - What could break with this change
- [ ] **Performance impact** - Estimate Git clone overhead
- [ ] **Network dependencies** - Document new network requirements
- [ ] **Rollback complexity** - Plan for quick revert if needed

## 📋 **Phase 2: Design and Planning (2-3 hours)**

### 2.1 New Workflow Design
- [ ] **Design new build.yaml structure** - Git source instead of raw data
- [ ] **Parameter redesign** - Replace `dockerfileContent` with Git parameters
- [ ] **Context handling** - Ensure proper build context in Git workspace
- [ ] **Error handling** - Plan for Git clone failures and authentication issues

### 2.2 Migration Strategy
- [ ] **Dual-mode approach** - Support both old and new methods temporarily
- [ ] **Feature flag design** - Allow switching between methods
- [ ] **Testing strategy** - Comprehensive validation approach
- [ ] **Rollout plan** - Gradual migration with safety checkpoints

### 2.3 Documentation Planning
- [ ] **Update build scripts** - Modify build.sh for new parameters
- [ ] **Update README** - Document new build process
- [ ] **Create troubleshooting guide** - Common issues and solutions
- [ ] **Migration guide** - Steps for teams to adopt new method

## 📋 **Phase 3: Implementation (3-4 hours)**

### 3.1 Core Implementation
- [ ] **Create build-v2.yaml** - New Argo workflow with Git source
- [ ] **Update build.sh** - Support new Git-based parameters
- [ ] **Add authentication** - Configure Git credentials in Kubernetes
- [ ] **Test basic functionality** - Ensure Git clone and build works

### 3.2 Enhanced Features
- [ ] **Add commit hash logging** - Track exact source used for builds
- [ ] **Improve error messages** - Better diagnostics for Git issues
- [ ] **Add build context validation** - Verify all dependencies present
- [ ] **Performance optimization** - Minimize Git clone overhead

### 3.3 Backwards Compatibility
- [ ] **Maintain old method** - Keep current parameter-based approach
- [ ] **Add feature toggle** - Environment variable to switch methods
- [ ] **Update Makefile** - Support both build methods
- [ ] **Document differences** - Clear comparison between approaches

## 📋 **Phase 4: Testing and Validation (2-3 hours)**

### 4.1 Functional Testing
- [ ] **Basic build test** - Simple Dockerfile build from Git
- [ ] **CUDA vs CPU builds** - Test both image variants
- [ ] **Different branches/tags** - Verify Git revision handling
- [ ] **Authentication test** - Validate Git credentials work

### 4.2 Integration Testing
- [ ] **End-to-end workflow** - Complete build.sh execution
- [ ] **Makefile targets** - All make targets work correctly  
- [ ] **CI/CD pipeline** - Integration with existing automation
- [ ] **Multi-environment** - Test across different clusters/namespaces

### 4.3 Performance Testing
- [ ] **Build time comparison** - Measure Git clone overhead
- [ ] **Resource usage** - Monitor CPU/memory during Git operations
- [ ] **Network bandwidth** - Measure Git clone impact
- [ ] **Concurrent builds** - Test multiple simultaneous builds

### 4.4 Error Scenario Testing
- [ ] **Git authentication failure** - Invalid credentials
- [ ] **Network connectivity issues** - Repository unreachable
- [ ] **Invalid Git revision** - Non-existent branch/tag
- [ ] **Build context missing** - Required files not in repo

## 📋 **Phase 5: Migration and Rollout (1-2 hours)**

### 5.1 Staged Rollout
- [ ] **Development environment** - Test in dev cluster first
- [ ] **Single service test** - Migrate one service/image
- [ ] **Limited production** - Small subset of builds
- [ ] **Full migration** - All builds using new method

### 5.2 Monitoring and Validation
- [ ] **Build success rate** - Monitor for failures
- [ ] **Performance metrics** - Track build time changes
- [ ] **Error patterns** - Identify common issues
- [ ] **User feedback** - Gather developer experience feedback

### 5.3 Documentation Updates
- [ ] **Update main README** - Reflect new build process
- [ ] **Update CLAUDE.md** - Document new architecture
- [ ] **Create troubleshooting docs** - Common issues and solutions
- [ ] **Archive old documentation** - Keep for reference but mark as deprecated

## 📋 **Phase 6: Cleanup and Optimization (1 hour)**

### 6.1 Remove Legacy Code
- [ ] **Remove dockerfileContent parameter** - Clean up build.yaml
- [ ] **Update build.sh** - Remove old parameter handling
- [ ] **Clean up documentation** - Remove references to old method
- [ ] **Update tests** - Remove tests for deprecated functionality

### 6.2 Final Optimization
- [ ] **Git clone optimization** - Shallow clones, specific paths
- [ ] **Caching improvements** - Cache Git repositories if possible
- [ ] **Resource optimization** - Right-size containers for Git operations
- [ ] **Monitoring setup** - Long-term performance tracking

## 🎯 **Key Deliverables**

### Implementation Files
1. **`build-v2.yaml`** - New Argo workflow with Git source
2. **`build-v2.sh`** - Updated build script with Git parameters
3. **`migration-guide.md`** - Step-by-step migration instructions
4. **`troubleshooting.md`** - Common issues and solutions

### Documentation Updates
1. **Updated README.md** - New build process documentation
2. **Updated CLAUDE.md** - Architecture changes
3. **Performance comparison** - Before/after metrics
4. **Security improvements** - Benefits of Git-based approach

## ⏱️ **Timeline Estimate**

- **Total Effort:** 10-15 hours
- **Calendar Time:** 2-3 days (with testing and validation)
- **Critical Path:** Design → Implementation → Testing → Migration

## 🚨 **Risk Mitigation**

### High-Risk Items
1. **Git authentication in Kubernetes** - Complex to configure correctly
2. **Build context dependencies** - May miss required files
3. **Performance impact** - Git clone could slow builds significantly
4. **Network dependencies** - New failure point for builds

### Mitigation Strategies
1. **Thorough testing** - Comprehensive test suite before migration
2. **Dual-mode support** - Keep old method as fallback
3. **Monitoring** - Close monitoring during rollout
4. **Quick rollback** - Automated revert process

## ✅ **Success Criteria**

- [ ] All builds work with Git repository source
- [ ] Build times increase by less than 20%
- [ ] Git commit hash visible in build logs
- [ ] No parameter size limitations
- [ ] Easy rollback to previous method
- [ ] Comprehensive documentation updated
- [ ] All team members trained on new process