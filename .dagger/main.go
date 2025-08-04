package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	
	"dagger/test/internal/dagger"
)

type Build struct{}


// BuildFromGit builds using Dockerfile from a Git repository with authentication
func (m *Build) BuildFromGit(
	ctx context.Context,
	// Git repository URL (supports both HTTPS and SSH)
	gitRepo string,
	// Git reference (branch, tag, commit)
	// +default="main"
	gitRef string,
	// Git authentication token (Personal Access Token for HTTPS auth)
	// +optional
	gitToken string,
	// Git username (for username/token auth, required for Azure DevOps HTTPS)
	// +optional
	gitUsername string,
	// SSH private key content (for SSH authentication)
	// +optional
	sshPrivateKey string,
	// Enable CUDA support
	// +default="true"  
	enableCuda bool,
	// Image tag
	// +default="v14.1.1"
	imageTag string,
	// Registry URL
	// +default="registry.ra.se:5002"
	registry string,
	// Image repository name
	// +default="airiksarkivet/devenv"
	imageRepository string,
	// Kaniko verbosity level
	// +default="info"
	verbosity string,
) (string, error) {
	var source *dagger.Directory
	
	// Auto-detect SSH key if not provided and SSH URL is used
	if sshPrivateKey == "" && (strings.HasPrefix(gitRepo, "ssh://") || strings.HasPrefix(gitRepo, "git@")) {
		// Try to read SSH key from default path
		if keyContent, err := os.ReadFile(os.Getenv("HOME") + "/.ssh/id_rsa"); err == nil {
			sshPrivateKey = string(keyContent)
		}
	}
	
	if sshPrivateKey != "" {
		// Use SSH key authentication
		source = m.cloneWithSSH(ctx, gitRepo, gitRef, sshPrivateKey)
	} else if gitToken != "" {
		// Use Git credentials helper approach for HTTPS authentication
		source = m.cloneWithCredentials(ctx, gitRepo, gitRef, gitToken, gitUsername)
	} else {
		// Public repository - use direct Git access
		git := dag.Git(gitRepo)
		source = git.Branch(gitRef).Tree()
	}
	
	// Determine final tag
	finalTag := imageTag
	if !enableCuda {
		finalTag = imageTag + "-cpu"
	}
	
	destination := fmt.Sprintf("%s/%s:%s", registry, imageRepository, finalTag)
	
	// Create Kaniko executor with Git source (no caching)
	kaniko := dag.Container().
		From("gcr.io/kaniko-project/executor:latest").
		WithMountedDirectory("/workspace", source).
		WithExec([]string{
			"/kaniko/executor",
			"--context=/workspace/Riksarkivets-Development-Template",
			"--dockerfile=/workspace/Riksarkivets-Development-Template/Dockerfile",
			"--destination=" + destination,
			"--insecure",
			"--insecure-registry=" + registry,
			"--skip-tls-verify-registry=" + registry,
			"--build-arg=ENABLE_CUDA=" + fmt.Sprintf("%t", enableCuda),
			"--build-arg=REGISTRY=" + registry,
			"--cache=false",
			// Caching disabled to avoid layer inconsistencies
			// "--cache-dir=/cache",
			// "--cache-repo=" + fmt.Sprintf("%s/%s/cache-v4", registry, imageRepository),
			// "--cache-copy-layers",
			// "--cache-ttl=168h", // 7 days cache TTL
			"--verbosity=" + verbosity,
		})
	
	// Execute build
	output, err := kaniko.Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("kaniko build failed: %w", err)
	}
	
	return fmt.Sprintf("Successfully built image: %s\nSource: %s@%s\nOutput: %s", destination, gitRepo, gitRef, output), nil
}

// cloneWithCredentials uses a container with Git credentials helper to clone authenticated repositories
func (m *Build) cloneWithCredentials(ctx context.Context, gitRepo, gitRef, gitToken, gitUsername string) *dagger.Directory {
	// Create Git credentials configuration
	gitConfig := `[credential]
	helper = store
`
	
	// Determine credentials format based on server
	var credentialsContent string
	if strings.HasPrefix(gitRepo, "https://devops.ra.se/") {
		if gitUsername != "" {
			// Azure DevOps with username
			credentialsContent = fmt.Sprintf("https://%s:%s@devops.ra.se\n", gitUsername, gitToken)
		} else {
			// Azure DevOps with empty username (PAT only)
			credentialsContent = fmt.Sprintf("https://:%s@devops.ra.se\n", gitToken)
		}
	} else {
		// GitHub or other Git servers
		credentialsContent = fmt.Sprintf("https://:%s@github.com\n", gitToken)
	}
	
	// Create a container with Git and clone the repository using credentials helper
	cloneContainer := dag.Container().
		From("alpine/git:latest").
		WithNewFile("/root/.gitconfig", gitConfig).
		WithNewFile("/root/.git-credentials", credentialsContent).
		WithExec([]string{"git", "clone", "--depth=1", "--branch=" + gitRef, gitRepo, "/workspace"})
	
	// Return the cloned directory
	return cloneContainer.Directory("/workspace")
}

// BuildCuda builds CUDA-enabled image from Git repository
func (m *Build) BuildCuda(
	ctx context.Context,
	// Git repository URL
	gitRepo string,
	// Image tag  
	// +default="v14.1.1"
	imageTag string,
	// Git reference
	// +default="main"
	gitRef string,
	// Git authentication token
	// +optional
	gitToken string,
	// Git username (required for Azure DevOps)
	// +optional
	gitUsername string,
	// SSH private key content (for SSH authentication)
	// +optional
	sshPrivateKey string,
	// Kaniko verbosity level
	// +default="info"
	verbosity string,
) (string, error) {
	return m.BuildFromGit(ctx, gitRepo, gitRef, gitToken, gitUsername, sshPrivateKey, true, imageTag, "registry.ra.se:5002", "airiksarkivet/devenv", verbosity)
}

// BuildCpu builds CPU-only image from Git repository
func (m *Build) BuildCpu(
	ctx context.Context,
	// Git repository URL
	gitRepo string,
	// Image tag
	// +default="v14.1.1"
	imageTag string,
	// Git reference
	// +default="main"
	gitRef string,
	// Git authentication token
	// +optional
	gitToken string,
	// Git username (required for Azure DevOps)
	// +optional
	gitUsername string,
	// SSH private key content (for SSH authentication)
	// +optional
	sshPrivateKey string,
	// Kaniko verbosity level
	// +default="info"
	verbosity string,
) (string, error) {
	return m.BuildFromGit(ctx, gitRepo, gitRef, gitToken, gitUsername, sshPrivateKey, false, imageTag, "registry.ra.se:5002", "airiksarkivet/devenv", verbosity)
}

// GetBuildCommand returns example dagger commands for different scenarios
func (m *Build) GetBuildCommand(
	// Enable CUDA support
	// +default="true"
	enableCuda bool,
	// Service name
	// +default="devenv"
	serviceName string,
	// Image tag
	// +default="v14.1.1"
	imageTag string,
) string {
	cudaFlag := "true"
	if !enableCuda {
		cudaFlag = "false"
	}
	
	return fmt.Sprintf(`Azure DevOps Server builds:

# Build from your Azure DevOps repository:
dagger call build-from-git \
  --git-repo="https://devops.ra.se/DataLab/Datalab/_git/coder-templates" \
  --git-username="your-username" \
  --git-token="your-personal-access-token" \
  --enable-cuda=%s \
  --image-tag=%s

# CUDA shortcut:
dagger call build-cuda \
  --git-repo="https://devops.ra.se/DataLab/Datalab/_git/coder-templates" \
  --git-username="your-username" \
  --git-token="your-pat-token" \
  --image-tag=%s

# CPU shortcut:
dagger call build-cpu \
  --git-repo="https://devops.ra.se/DataLab/Datalab/_git/coder-templates" \
  --git-username="your-username" \
  --git-token="your-pat-token" \
  --image-tag=%s

# Public repositories (no auth needed):
dagger call build-from-git \
  --git-repo="https://github.com/user/public-repo" \
  --enable-cuda=%s \
  --image-tag=%s`, 
		cudaFlag, imageTag, imageTag, imageTag, cudaFlag, imageTag)
}

// Hello returns usage information
func (m *Build) Hello() string {
    return `🚀 Dagger Build Pipeline Ready!

✅ Azure DevOps Server Support:
  • Automatic credential embedding for devops.ra.se
  • Username + Personal Access Token authentication
  • Full build context from Git (no dockerfile size limits!)

Key functions:
• build-from-git: Full control with Azure DevOps auth
• build-cuda: CUDA-enabled shortcut  
• build-cpu: CPU-only shortcut
• build-from-dockerfile: Legacy method (still supported)

🔧 Setup: Create a Personal Access Token in Azure DevOps
📚 Examples: Run 'dagger call get-build-command' for usage examples

No more passing dockerfile content as parameters! 🎉`
}

// cloneWithSSH uses SSH key authentication to clone repositories
func (m *Build) cloneWithSSH(ctx context.Context, gitRepo, gitRef, sshPrivateKey string) *dagger.Directory {
	// Create SSH configuration
	sshConfig := `Host devops.ra.se
    HostName devops.ra.se
    Port 22
    User git
    IdentityFile /root/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host ssh.dev.azure.com
    HostName ssh.dev.azure.com
    User git
    IdentityFile /root/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
`
	
	// Handle different Git URL formats
	var cloneURL string
	if strings.HasPrefix(gitRepo, "ssh://") {
		// Already SSH URL, use as-is
		cloneURL = gitRepo
	} else if strings.HasPrefix(gitRepo, "https://devops.ra.se/") {
		// Convert HTTPS URL to SSH URL
		// https://devops.ra.se/DataLab/Datalab/_git/coder-templates
		// to ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates
		path := strings.Replace(gitRepo, "https://devops.ra.se/", "", 1)
		cloneURL = fmt.Sprintf("ssh://git@devops.ra.se:22/%s", path)
	} else {
		// Default to original URL
		cloneURL = gitRepo
	}
	
	// Create a container with Git and SSH setup
	cloneContainer := dag.Container().
		From("alpine/git:latest").
		WithExec([]string{"apk", "add", "--no-cache", "openssh-client"}).
		WithExec([]string{"mkdir", "-p", "/root/.ssh"}).
		WithNewFile("/root/.ssh/id_rsa", sshPrivateKey).
		WithExec([]string{"chmod", "600", "/root/.ssh/id_rsa"}).
		WithNewFile("/root/.ssh/config", sshConfig).
		WithExec([]string{"git", "clone", "--depth=1", "--branch=" + gitRef, cloneURL, "/workspace"})
	
	// Return the cloned directory
	return cloneContainer.Directory("/workspace")
}
