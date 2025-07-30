# Testing Plan - Dockerfile Repository Refactor

## 🎯 **Testing Objectives**

Ensure the Git-based Dockerfile delivery system works reliably, performs acceptably, and maintains compatibility with existing workflows.

## 📋 **Test Categories**

### 1. Functional Testing

#### 1.1 Basic Git Integration Tests
- [ ] **Simple Git clone test** - Basic repository cloning works
- [ ] **Dockerfile location test** - Dockerfile found at expected path
- [ ] **Build context test** - All required files available for build
- [ ] **Multiple Dockerfile test** - Different Dockerfiles in same repo

#### 1.2 Git Revision Tests
```bash
# Test different Git references
USE_GIT_SOURCE=true ./build.sh true devenv v13.6.0 registry.ra.se:5002 # main branch
USE_GIT_SOURCE=true GIT_REVISION=fb50467 ./build.sh # specific commit
USE_GIT_SOURCE=true GIT_REVISION=v1.0.0 ./build.sh # tag reference
```

#### 1.3 Authentication Tests
- [ ] **Valid credentials test** - Successful authentication to private repo
- [ ] **Invalid credentials test** - Graceful failure with clear error message
- [ ] **Token expiration test** - Handles expired authentication tokens
- [ ] **SSH key test** - SSH-based authentication works correctly

#### 1.4 Build Variant Tests
- [ ] **CUDA build test** - `ENABLE_CUDA=true` works with Git source
- [ ] **CPU build test** - `ENABLE_CUDA=false` works with Git source
- [ ] **Parameter consistency** - Same parameters produce same results

### 2. Integration Testing

#### 2.1 End-to-End Workflow Tests
```bash
# Complete workflow testing
make kaniko-build-cuda    # Test Makefile integration
make kaniko-build-cpu     # Test both build variants
./build.sh               # Test direct script usage  
```

#### 2.2 Dual-Mode Testing
- [ ] **Feature flag toggle** - Switch between Git and parameter modes
- [ ] **Result consistency** - Both methods produce identical images  
- [ ] **Performance comparison** - Document timing differences
- [ ] **Fallback mechanism** - Automatic fallback if Git fails

#### 2.3 CI/CD Pipeline Integration
- [ ] **Argo workflow execution** - Complete workflow runs successfully
- [ ] **Kubernetes resource usage** - Proper resource allocation for Git operations
- [ ] **Build artifact verification** - Images pushed to registry correctly
- [ ] **Log analysis** - Build logs contain Git commit information

### 3. Performance Testing

#### 3.1 Build Time Analysis
```bash
# Baseline measurement (current method)
time make kaniko-build

# Git-based measurement  
time USE_GIT_SOURCE=true make kaniko-build

# Performance targets:
# - Git clone overhead: < 60 seconds
# - Total build time increase: < 20%
```

#### 3.2 Resource Usage Testing
- [ ] **Memory usage** - Git clone memory footprint
- [ ] **Storage usage** - Git repository size impact
- [ ] **Network bandwidth** - Git clone network usage
- [ ] **Concurrent builds** - Multiple simultaneous Git clones

#### 3.3 Scalability Testing
- [ ] **Multiple simultaneous builds** - 5+ concurrent builds
- [ ] **Large repository test** - Performance with large Git repos
- [ ] **Network congestion test** - Git clone under network stress
- [ ] **Build queue impact** - Effect on build queue processing

### 4. Error Handling and Recovery Testing

#### 4.1 Git-Related Failures
- [ ] **Repository unavailable** - Git server down or unreachable
- [ ] **Invalid repository URL** - Non-existent repository
- [ ] **Authentication failure** - Invalid credentials or expired tokens
- [ ] **Network timeout** - Git clone times out
- [ ] **Corrupted clone** - Git repository corruption during clone

#### 4.2 Build Context Failures
- [ ] **Missing Dockerfile** - Dockerfile not found at expected path
- [ ] **Missing dependencies** - Required files not in repository
- [ ] **Permission issues** - File permission problems in Git workspace
- [ ] **Large file handling** - Git LFS files or large binaries

#### 4.3 Recovery Mechanisms
- [ ] **Automatic retry** - Git operations retry on transient failures
- [ ] **Fallback to parameter mode** - Graceful degradation
- [ ] **Clear error messages** - Actionable error information
- [ ] **Build failure notifications** - Proper alerting on failures

### 5. Security Testing

#### 5.1 Credential Security
- [ ] **Credential exposure** - No credentials in logs or parameters
- [ ] **Secret rotation** - Handles credential updates gracefully
- [ ] **Access control** - Only authorized builds can access repository
- [ ] **Audit trail** - Git operations properly logged

#### 5.2 Repository Security
- [ ] **Branch protection** - Cannot access protected branches without permission
- [ ] **Repository validation** - Ensures repository URL is authorized
- [ ] **Content validation** - Basic validation of Dockerfile content
- [ ] **Supply chain security** - Git commit signature verification

## 🧪 **Test Implementation**

### Test Environment Setup
```bash
# Set up test environment
export TEST_REGISTRY="test-registry.ra.se:5002"
export TEST_NAMESPACE="ci-test"
export USE_GIT_SOURCE=true
export GIT_REPO="https://devops.ra.se/DataLab/Datalab/_git/coder-templates"
```

### Automated Test Suite
```bash
#!/bin/bash
# test-git-builds.sh

echo "🧪 Running Git-based build tests..."

# Test 1: Basic functionality
echo "Test 1: Basic Git build"
USE_GIT_SOURCE=true ./build.sh true devenv test-v1.0 $TEST_REGISTRY
test_result=$?

# Test 2: Different Git revision
echo "Test 2: Specific Git commit"
USE_GIT_SOURCE=true GIT_REVISION=fb50467 ./build.sh true devenv test-v1.1 $TEST_REGISTRY
test_result=$?

# Test 3: CPU build variant
echo "Test 3: CPU build variant"
USE_GIT_SOURCE=true ./build.sh false devenv test-v1.0-cpu $TEST_REGISTRY
test_result=$?

# Performance test
echo "Test 4: Performance comparison"
time USE_GIT_SOURCE=false ./build.sh > /tmp/param-build.log 2>&1
time USE_GIT_SOURCE=true ./build.sh > /tmp/git-build.log 2>&1

echo "✅ All tests completed. Check logs for results."
```

### Manual Test Scenarios
```bash
# Scenario 1: Authentication failure simulation
# Remove or corrupt Git credentials, verify graceful failure

# Scenario 2: Network connectivity issues  
# Block network access to Git repository, test timeout handling

# Scenario 3: Repository corruption
# Clone repository with intentional corruption, test error handling

# Scenario 4: Large repository performance
# Test with repository containing large files or extensive history
```

## 📊 **Test Data Collection**

### Performance Metrics
```bash
# Collect these metrics for each test run:
echo "Build Method: Git-based"
echo "Git Clone Time: $(git_clone_duration)"
echo "Total Build Time: $(total_build_time)"
echo "Memory Usage Peak: $(memory_peak)"
echo "Network Data Transfer: $(network_usage)"
echo "Git Commit SHA: $(git_commit_sha)"
```

### Test Results Template
```markdown
## Test Results - [Date]

### Functional Tests
- ✅ Basic Git integration: PASS
- ✅ Authentication: PASS  
- ✅ Build variants: PASS
- ❌ Large repository: FAIL (timeout after 5 minutes)

### Performance Tests
- Git clone time: 45 seconds
- Total build time increase: 12% (acceptable)
- Memory usage: +200MB (within limits)
- Network usage: 50MB download

### Issues Found
1. Timeout with repositories > 1GB
2. Error message unclear for authentication failures
3. Git LFS files not handled correctly

### Recommendations
1. Implement shallow clone optimization
2. Improve error message clarity
3. Add Git LFS support
```

## 🔧 **Test Tools and Scripts**

### Test Utilities
```bash
# build-test-utility.sh
#!/bin/bash

function run_build_test() {
    local test_name=$1
    local git_source=$2
    local enable_cuda=$3
    
    echo "🧪 Running test: $test_name"
    start_time=$(date +%s)
    
    USE_GIT_SOURCE=$git_source ./build.sh $enable_cuda devenv test-build
    result=$?
    
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [ $result -eq 0 ]; then
        echo "✅ $test_name: PASS (${duration}s)"
    else
        echo "❌ $test_name: FAIL (${duration}s)"
    fi
    
    return $result
}

# Performance comparison utility
function compare_performance() {
    echo "📊 Performance Comparison"
    
    # Baseline (parameter method)
    echo "Testing parameter-based method..."
    time USE_GIT_SOURCE=false ./build.sh > param_build.log 2>&1
    param_time=$?
    
    # New method (Git-based)
    echo "Testing Git-based method..."
    time USE_GIT_SOURCE=true ./build.sh > git_build.log 2>&1
    git_time=$?
    
    echo "Results:"
    echo "Parameter method: ${param_time}s"
    echo "Git method: ${git_time}s"
    echo "Difference: $((git_time - param_time))s"
}
```

### Monitoring and Validation
```bash
# build-monitor.sh
#!/bin/bash

function monitor_build() {
    local workflow_name=$1
    
    echo "📊 Monitoring build: $workflow_name"
    
    # Watch build progress
    argo logs --follow $workflow_name -n ci
    
    # Collect metrics
    start_time=$(argo get $workflow_name -n ci -o json | jq -r '.status.startedAt')
    end_time=$(argo get $workflow_name -n ci -o json | jq -r '.status.finishedAt')
    
    # Calculate duration
    duration=$(date -d "$end_time" +%s) - $(date -d "$start_time" +%s)
    echo "Build duration: ${duration} seconds"
    
    # Check for Git commit in logs
    git_commit=$(argo logs $workflow_name -n ci | grep -o 'commit [a-f0-9]*' | head -1)
    echo "Git commit used: $git_commit"
}
```

## ✅ **Test Acceptance Criteria**

### Functional Requirements
- [ ] **100% test pass rate** for core functionality
- [ ] **Git authentication works** with configured credentials
- [ ] **Both CUDA and CPU builds** work correctly
- [ ] **Build artifacts identical** to parameter-based method

### Performance Requirements  
- [ ] **Build time increase < 20%** compared to current method
- [ ] **Git clone time < 60 seconds** for typical repository
- [ ] **Memory usage increase < 500MB** during Git operations
- [ ] **Network usage reasonable** (< 100MB for typical clone)

### Reliability Requirements
- [ ] **Error handling comprehensive** for all failure modes
- [ ] **Recovery mechanisms work** for transient failures
- [ ] **Rollback capability tested** and functional
- [ ] **Clear error messages** for troubleshooting

### Security Requirements
- [ ] **No credential exposure** in logs or workflow parameters
- [ ] **Git operations properly authenticated** and authorized
- [ ] **Audit trail complete** for all Git operations
- [ ] **Repository access controls** respected

## 📅 **Testing Schedule**

### Week 1: Test Preparation
- Set up test environment and tools
- Prepare test data and scenarios
- Create automated test scripts

### Week 2: Functional Testing
- Run all functional test scenarios
- Document issues and fixes
- Validate core functionality

### Week 3: Performance and Integration Testing
- Conduct performance benchmarks
- Test integration with existing workflows
- Stress test with concurrent builds

### Week 4: Security and Error Handling
- Security testing and validation
- Error scenario testing
- Recovery mechanism validation

### Week 5: User Acceptance Testing
- Team testing with real workflows
- Documentation and training validation
- Final sign-off for migration