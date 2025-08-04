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

// BuildCpu builds CPU-only image from current directory
func (m *Build) BuildCpu(
	ctx context.Context,
	// Image tag
	// +default="v14.1.3"
	imageTag string,
	// Kaniko verbosity level
	// +default="info"
	verbosity string,
) (string, error) {
	source := dag.CurrentModule().Source().Directory("..")
	return m.BuildLocal(ctx, source, false, imageTag, "registry.ra.se:5002", "airiksarkivet/devenv", verbosity)
}

// BuildCuda builds CUDA-enabled image from current directory
func (m *Build) BuildCuda(
	ctx context.Context,
	// Image tag
	// +default="v14.1.3"
	imageTag string,
	// Kaniko verbosity level
	// +default="info"
	verbosity string,
) (string, error) {
	source := dag.CurrentModule().Source().Directory("..")
	return m.BuildLocal(ctx, source, true, imageTag, "registry.ra.se:5002", "airiksarkivet/devenv", verbosity)
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

# Build from current directory:
dagger call build-from-current-dir --enable-cuda=%s --image-tag=%s

# CPU build shortcut:
dagger call build-cpu --image-tag=%s

# CUDA build shortcut:
dagger call build-cuda --image-tag=%s

# Build with custom directory:
dagger call build-local --source="./" --enable-cuda=%s --image-tag=%s`, 
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
• build-from-current-dir: Build from project root
• build-cpu: CPU build shortcut
• build-cuda: CUDA build shortcut
• build-local: Build from specified directory

📚 Examples: Run 'dagger call get-build-command' for usage examples`
}