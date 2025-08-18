package main

import (
	"context"
	"crypto/sha256"
	"dagger/test/internal/dagger"
	"fmt"
	"sort"
	"strings"
	"time"
)

type Build struct{}

// TagCalculatorFunc defines a function type for calculating image tags based on parameters
type TagCalculatorFunc func(baseTag string, envVars []string, imageRepository string) string

// DefaultTagCalculator provides the default tag calculation logic
func DefaultTagCalculator(baseTag string, envVars []string, imageRepository string) string {
	finalTag := baseTag
	for _, envVar := range envVars {
		if envVar == "ENABLE_CUDA=false" {
			finalTag = baseTag + "-cpu"
			break
		}
	}
	return finalTag
}

// ShaBasedTagCalculator calculates a SHA-based tag from parameters, with special cases
func ShaBasedTagCalculator(baseTag string, envVars []string, imageRepository string) string {
	// Special case: CPU-only builds get a fixed suffix
	for _, envVar := range envVars {
		if envVar == "ENABLE_CUDA=false" {
			return baseTag + "-cpu"
		}
	}

	// For other combinations, calculate SHA based on sorted parameters
	sort.Strings(envVars)
	input := fmt.Sprintf("%s-%s-%s", baseTag, imageRepository, strings.Join(envVars, ","))
	hash := sha256.Sum256([]byte(input))
	shortHash := fmt.Sprintf("%x", hash)[:8]
	return baseTag + "-" + shortHash
}

// BuildLocal builds using Dockerfile from a local directory with custom environment variables
func (m *Build) BuildLocal(
	ctx context.Context,
	// Local directory to build from
	source *dagger.Directory,
	// Image repository name
	imageRepository string,
	// Environment variables for build customization (KEY=VALUE format)
	// +default=[]
	envVars []string,
	// Image tag
	// +default="v14.1.3"
	imageTag string,
	// Registry URL
	// +default="docker.io"
	registry string,
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
			BuildArgs:  buildArgs,
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
dagger call build-local --source="./Riksarkivets-Development-Template" --image-repository="riksarkivet/coder-workspace-ml" --env-vars="ENABLE_CUDA=false" --image-tag=%s

# CUDA build (local only):
dagger call build-local --source="./Riksarkivets-Development-Template" --image-repository="riksarkivet/coder-workspace-ml" --env-vars="ENABLE_CUDA=true" --image-tag=%s

# Custom build with multiple environment variables:
dagger call build-local --source="./Riksarkivets-Development-Template" --image-repository="riksarkivet/coder-workspace-ml" --env-vars="ENABLE_CUDA=true" --env-vars="PYTHON_VERSION=3.12" --env-vars="CUSTOM_TOOL=enabled" --image-tag=%s

# Build and publish to registry:
dagger call build-and-publish --source="./Riksarkivets-Development-Template" --image-repository="riksarkivet/coder-workspace-ml" --username="myuser" --password="mypass" --env-vars="ENABLE_CUDA=true" --image-tag=%s

# Quick CPU build:
dagger call quick-cpu-build --source="./Riksarkivets-Development-Template" --image-repository="riksarkivet/coder-workspace-ml"

# Quick CUDA build:
dagger call quick-cuda-build --source="./Riksarkivets-Development-Template" --image-repository="riksarkivet/coder-workspace-ml"`,
		imageTag, imageTag, imageTag, imageTag)
}

// BuildAndPublishWithService builds using Dockerfile and publishes to a registry service with custom environment variables
func (m *Build) BuildAndPublish(
	ctx context.Context,
	// Local directory to build from
	source *dagger.Directory,
	// Image repository name
	imageRepository string,

	// Registry username (optional for local registry)
	username string,
	// Registry password/token (optional for local registry)
	password *dagger.Secret,
	// Environment variables for build customization (KEY=VALUE format)
	// +default=["ENABLE_CUDA=true"]
	envVars []string,
	// Image tag
	// +default="v14.1.3"
	imageTag string,
	// Registry URL
	// +default="registry:5000"
	registry string,

	// Registry service to bind
	registryService *dagger.Service,
) (string, error) {
	// Calculate final tag using the default function
	finalTag := DefaultTagCalculator(imageTag, envVars, imageRepository)

	destination := fmt.Sprintf("%s/%s:%s", registry, imageRepository, finalTag)

	// Convert environment variables to build args
	buildArgs := []dagger.BuildArg{
		{Name: "REGISTRY", Value: strings.Split(registry, ":")[0]}, // Use just the hostname for REGISTRY arg
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
			BuildArgs:  buildArgs,
		})

	// For local registry with service binding, use skopeo to push
	if registryService != nil && strings.Contains(registry, "registry:5000") {
		// First export the image to OCI format
		tarFile := container.AsTarball()

		// Use skopeo to push to the local registry
		_, err := dag.Container().From("quay.io/skopeo/stable").
			WithServiceBinding("registry", registryService).
			WithMountedFile("/tmp/image.tar", tarFile).
			WithEnvVariable("BUST", time.Now().String()).
			WithExec([]string{"copy", "--dest-tls-verify=false", "docker-archive:/tmp/image.tar", fmt.Sprintf("docker://%s", destination)}, dagger.ContainerWithExecOpts{UseEntrypoint: true}).
			Sync(ctx)

		if err != nil {
			return "", fmt.Errorf("failed to push to local registry: %w", err)
		}

		return fmt.Sprintf("Successfully built and pushed image to local registry: %s", destination), nil
	}

	// For external registries, use standard publish
	var addr string
	var err error
	if username != "" && password != nil {
		// External registry with authentication
		addr, err = container.WithRegistryAuth(registry, username, password).Publish(ctx, destination)
	} else {
		// External registry without authentication
		addr, err = container.Publish(ctx, destination)
	}

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
	// Image repository name
	// +default="riksarkivet/coder-workspace-ml"
	imageRepository string,
) (*dagger.Container, error) {
	return m.BuildLocal(ctx, source, imageRepository, []string{"ENABLE_CUDA=false"}, "latest", "docker.io")
}

// QuickCudaBuild is a convenience function for CUDA builds
func (m *Build) QuickCudaBuild(
	ctx context.Context,
	// Local directory to build from
	source *dagger.Directory,
	// Image repository name
	// +default="riksarkivet/coder-workspace-ml"
	imageRepository string,
) (*dagger.Container, error) {
	return m.BuildLocal(ctx, source, imageRepository, []string{"ENABLE_CUDA=true"}, "latest", "docker.io")
}
