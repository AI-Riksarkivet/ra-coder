package main

import (
	"context"
	"fmt"
	"strings"
	
	"dagger/test/internal/dagger"
)

type Build struct{}


// BuildLocal builds using Dockerfile from a local directory
func (m *Build) BuildLocal(
	ctx context.Context,
	// Local directory to build from
	source *dagger.Directory,
	// Enable CUDA support
	// +default="true"
	enableCuda bool,
	// Image tag
	// +default="v14.1.3"
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
	// Determine final tag
	finalTag := imageTag
	if !enableCuda {
		finalTag = imageTag + "-cpu"
	}
	
	destination := fmt.Sprintf("%s/%s:%s", registry, imageRepository, finalTag)
	
	// Create Kaniko executor with local source
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
			"--verbosity=" + verbosity,
		})
	
	// Execute build
	output, err := kaniko.Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("kaniko build failed: %w", err)
	}
	
	return fmt.Sprintf("Successfully built image: %s\nSource: local directory\nOutput: %s", destination, output), nil
}

// BuildFromGit builds using Dockerfile from a Git repository with authentication
func (m *Build) BuildFromGit(
	ctx context.Context,
	// Git repository URL (HTTPS only)
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
	// Enable CUDA support
	// +default="true"  
	enableCuda bool,
	// Image tag
	// +default="v14.1.3"
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
	
	if gitToken != "" {
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
		From("mcr.microsoft.com/devcontainers/base:ubuntu").
		WithExec([]string{"apt-get", "update"}).
		WithExec([]string{"apt-get", "install", "-y", "git"}).
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
	// +default="v14.1.3"
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
	// Kaniko verbosity level
	// +default="info"
	verbosity string,
) (string, error) {
	return m.BuildFromGit(ctx, gitRepo, gitRef, gitToken, gitUsername, true, imageTag, "registry.ra.se:5002", "airiksarkivet/devenv", verbosity)
}

// BuildCpu builds CPU-only image from Git repository
func (m *Build) BuildCpu(
	ctx context.Context,
	// Git repository URL
	gitRepo string,
	// Image tag
	// +default="v14.1.3"
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
	// Kaniko verbosity level
	// +default="info"
	verbosity string,
) (string, error) {
	return m.BuildFromGit(ctx, gitRepo, gitRef, gitToken, gitUsername, false, imageTag, "registry.ra.se:5002", "airiksarkivet/devenv", verbosity)
}

// BuildFromCurrentDir builds from the current working directory
func (m *Build) BuildFromCurrentDir(
	ctx context.Context,
	// Enable CUDA support
	// +default="true"
	enableCuda bool,
	// Image tag
	// +default="v14.1.3"
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
	// Use parent directory as build context (go up from .dagger to project root)
	source := dag.CurrentModule().Source().Directory("..")
	return m.BuildLocal(ctx, source, enableCuda, imageTag, registry, imageRepository, verbosity)
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
	// +default="v14.1.3"
	imageTag string,
) string {
	cudaFlag := "true"
	if !enableCuda {
		cudaFlag = "false"
	}
	
	return fmt.Sprintf(`Build Commands:

# Build from local directory:
dagger call build-from-current-dir \
  --enable-cuda=%s \
  --image-tag=%s

# Build from HTTPS repository:
dagger call build-from-git \
  --git-repo="https://devops.ra.se/DataLab/Datalab/_git/coder-templates" \
  --git-username="your-username" \
  --git-token="your-personal-access-token" \
  --enable-cuda=%s \
  --image-tag=%s

# Public repositories (no auth needed):
dagger call build-from-git \
  --git-repo="https://github.com/user/public-repo" \
  --enable-cuda=%s \
  --image-tag=%s`, 
		cudaFlag, imageTag, cudaFlag, imageTag)
}

// Hello returns usage information
func (m *Build) Hello() string {
    return `🚀 Dagger Build Pipeline Ready!

✅ Build Options:
  • Build from local directory
  • Build from HTTPS Git repositories with authentication
  • Support for both CPU and CUDA builds

Key functions:
• build-from-current-dir: Build from local directory
• build-from-git: Build from HTTPS Git repository
• build-local: Build from specified directory
• build-cuda/build-cpu: Shortcuts for Git builds

📚 Examples: Run 'dagger call get-build-command' for usage examples`
}

