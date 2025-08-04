package main

import (
	"context"
	"fmt"
	
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
			"--context=/workspace",
			"--dockerfile=/workspace/Dockerfile",
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


// GetBuildCommand returns example dagger commands
func (m *Build) GetBuildCommand(
	// Enable CUDA support
	// +default="true"
	enableCuda bool,
	// Image tag
	// +default="v14.1.3"
	imageTag string,
) string {
	cudaFlag := "true"
	if !enableCuda {
		cudaFlag = "false"
	}
	
	return fmt.Sprintf(`Build Commands:

# CPU build:
dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=false --image-tag=%s

# CUDA build:
dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=true --image-tag=%s`, 
		cudaFlag, imageTag, imageTag, imageTag, cudaFlag, imageTag)
}

// Hello returns usage information
func (m *Build) Hello() string {
    return `🚀 Dagger Build Pipeline Ready!

✅ Build Options:
  • Build from local directory only
  • Support for both CPU and CUDA builds
  • Simple and fast local builds

Key functions:
• build-local: Build from specified directory (use "./Riksarkivets-Development-Template" as source)

📚 Examples: Run 'dagger call get-build-command' for usage examples`
}