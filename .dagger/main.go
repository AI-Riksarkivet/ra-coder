package main

import (
	"context"
	"fmt"
	"strings"
	
	"dagger/test/internal/dagger"
)

type Build struct{}

// BuildLocal builds using Dockerfile from a local directory with custom environment variables
func (m *Build) BuildLocal(
	ctx context.Context,
	// Local directory to build from
	source *dagger.Directory,
	// Environment variables for build customization (KEY=VALUE format)
	// +default=["ENABLE_CUDA=true"]
	envVars []string,
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
	// Convert environment variables to build args
	buildArgs := []dagger.BuildArg{
		{Name: "REGISTRY", Value: registry},
	}
	
	// Parse environment variables and add to build args
	for _, envVar := range envVars {
		if parts := strings.Split(envVar, "="); len(parts) == 2 {
			buildArgs = append(buildArgs, dagger.BuildArg{
				Name:  parts[0],
				Value: parts[1],
			})
		}
	}
	
	// Build the container using Dockerfile
	container := dag.Container().
		Build(source, dagger.ContainerBuildOpts{
			Dockerfile: "Dockerfile",
			BuildArgs: buildArgs,
		})
	
	return container, nil
}


// GetBuildCommand returns example dagger commands
func (m *Build) GetBuildCommand(
	// Image tag
	// +default="v14.1.3"
	imageTag string,
) string {
	return fmt.Sprintf(`Build Commands:

# CPU build (local only):
dagger call build-local --source="./Riksarkivets-Development-Template" --env-vars="ENABLE_CUDA=false" --image-tag=%s

# CUDA build (local only):
dagger call build-local --source="./Riksarkivets-Development-Template" --env-vars="ENABLE_CUDA=true" --image-tag=%s

# Custom build with multiple environment variables:
dagger call build-local --source="./Riksarkivets-Development-Template" --env-vars="ENABLE_CUDA=true" --env-vars="PYTHON_VERSION=3.12" --env-vars="CUSTOM_TOOL=enabled" --image-tag=%s

# Build and publish to registry:
dagger call build-and-publish --source="./Riksarkivets-Development-Template" --username="myuser" --password="mypass" --env-vars="ENABLE_CUDA=true" --image-tag=%s

# Quick CPU build:
dagger call quick-cpu-build --source="./Riksarkivets-Development-Template"

# Quick CUDA build:
dagger call quick-cuda-build --source="./Riksarkivets-Development-Template"`, 
		imageTag, imageTag, imageTag, imageTag)
}

// BuildAndPublish builds using Dockerfile and publishes to registry with custom environment variables
func (m *Build) BuildAndPublish(
	ctx context.Context,
	// Local directory to build from
	source *dagger.Directory,
	// Registry username
	username string,
	// Registry password/token (as a secret)
	password *dagger.Secret,
	// Environment variables for build customization (KEY=VALUE format)
	// +default=["ENABLE_CUDA=true"]
	envVars []string,
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
	// Determine final tag based on environment variables
	finalTag := imageTag
	for _, envVar := range envVars {
		if envVar == "ENABLE_CUDA=false" {
			finalTag = imageTag + "-cpu"
			break
		}
	}

	destination := fmt.Sprintf("%s/%s:%s", registry, imageRepository, finalTag)
	
	// Convert environment variables to build args
	buildArgs := []dagger.BuildArg{
		{Name: "REGISTRY", Value: registry},
	}
	
	// Parse environment variables and add to build args
	for _, envVar := range envVars {
		if parts := strings.Split(envVar, "="); len(parts) == 2 {
			buildArgs = append(buildArgs, dagger.BuildArg{
				Name:  parts[0],
				Value: parts[1],
			})
		}
	}
	
	// Build the container using Dockerfile
	container := dag.Container().
		Build(source, dagger.ContainerBuildOpts{
			Dockerfile: "Dockerfile",
			BuildArgs: buildArgs,
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
	return m.BuildLocal(ctx, source, []string{"ENABLE_CUDA=false"}, "latest", "docker.io", "riksarkivet/coder-workspace-ml")
}

// QuickCudaBuild is a convenience function for CUDA builds
func (m *Build) QuickCudaBuild(
	ctx context.Context,
	// Local directory to build from
	source *dagger.Directory,
) (*dagger.Container, error) {
	return m.BuildLocal(ctx, source, []string{"ENABLE_CUDA=true"}, "latest", "docker.io", "riksarkivet/coder-workspace-ml")
}