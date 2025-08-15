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
	// +default="docker.io"
	registry string,
	// Image repository name
	// +default="riksarkivet/coder-workspace-ml"
	imageRepository string,
) (*dagger.Container, error) {
	// Build the container using Dockerfile
	container := dag.Container().
		Build(source, dagger.ContainerBuildOpts{
			Dockerfile: "Dockerfile",
			BuildArgs: []dagger.BuildArg{
				{Name: "ENABLE_CUDA", Value: fmt.Sprintf("%t", enableCuda)},
				{Name: "REGISTRY", Value: registry},
			},
		})
	
	return container, nil
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

# CPU build (local only):
dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=false --image-tag=%s

# CUDA build (local only):
dagger call build-local --source="./Riksarkivets-Development-Template" --enable-cuda=true --image-tag=%s

# Build and publish to registry:
dagger call build-and-publish --source="./Riksarkivets-Development-Template" --username="myuser" --password="mypass" --enable-cuda=%s --image-tag=%s

# Quick CPU build:
dagger call quick-cpu-build --source="./Riksarkivets-Development-Template"

# Quick CUDA build:
dagger call quick-cuda-build --source="./Riksarkivets-Development-Template"`, 
		imageTag, imageTag, cudaFlag, imageTag)
}

// BuildAndPublish builds using Dockerfile and publishes to registry
func (m *Build) BuildAndPublish(
	ctx context.Context,
	// Local directory to build from
	source *dagger.Directory,
	// Registry username
	username string,
	// Registry password/token (as a secret)
	password *dagger.Secret,
	// Enable CUDA support
	// +default="true"
	enableCuda bool,
	// Image tag
	// +default="v14.1.3"
	imageTag string,
	// Registry URL
	// +default="docker.io"
	registry string,
	// Image repository name
	// +default="riksarkivet/coder-workspace-ml"
	imageRepository string,
) (string, error) {
	// Determine final tag
	finalTag := imageTag
	if !enableCuda {
		finalTag = imageTag + "-cpu"
	}

	destination := fmt.Sprintf("%s/%s:%s", registry, imageRepository, finalTag)
	
	// Build the container using Dockerfile
	container := dag.Container().
		Build(source, dagger.ContainerBuildOpts{
			Dockerfile: "Dockerfile",
			BuildArgs: []dagger.BuildArg{
				{Name: "ENABLE_CUDA", Value: fmt.Sprintf("%t", enableCuda)},
				{Name: "REGISTRY", Value: registry},
			},
		})
	
	// Publish to registry with authentication
	addr, err := container.WithRegistryAuth(registry, username, password).Publish(ctx, destination)
	if err != nil {
		return "", fmt.Errorf("failed to publish image: %w", err)
	}
	
	return fmt.Sprintf("Successfully built and pushed image: %s", addr), nil
}

// QuickCpuBuild is a convenience function for CPU-only builds
func (m *Build) QuickCpuBuild(
	ctx context.Context,
	// Local directory to build from
	source *dagger.Directory,
) (*dagger.Container, error) {
	return m.BuildLocal(ctx, source, false, "latest", "docker.io", "riksarkivet/coder-workspace-ml")
}

// QuickCudaBuild is a convenience function for CUDA builds
func (m *Build) QuickCudaBuild(
	ctx context.Context,
	// Local directory to build from
	source *dagger.Directory,
) (*dagger.Container, error) {
	return m.BuildLocal(ctx, source, true, "latest", "docker.io", "riksarkivet/coder-workspace-ml")
}