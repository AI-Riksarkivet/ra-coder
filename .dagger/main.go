package main

import (
	"context"
	"fmt"
)

type Test struct{}

// BuildImage builds a Docker image using Kaniko
func (m *Test) BuildImage(
	ctx context.Context,
	// Dockerfile content as string
	dockerfileContent string,
	// Enable CUDA support
	// +default="true"
	enableCuda bool,
	// Registry URL
	// +default="registry.ra.se:5002"
	registry string,
	// Image repository name
	// +default="airiksarkivet/devenv"
	imageRepository string,
	// Image tag
	// +default="v14.0.0"
	imageTag string,
	// Service name for tagging
	// +default="devenv"
	serviceName string,
) (string, error) {
	// Determine final tag based on CUDA support
	finalTag := imageTag
	if !enableCuda {
		finalTag = imageTag + "-cpu"
	}
	
	destination := fmt.Sprintf("%s/%s:%s", registry, imageRepository, finalTag)
	
	// Create Kaniko executor container using official image
	kaniko := dag.Container().
		From("gcr.io/kaniko-project/executor:latest").
		WithWorkdir("/workspace").
		WithNewFile("/workspace/Dockerfile", dockerfileContent).
		WithExec([]string{
			"/kaniko/executor",
			"--context=dir:///workspace",
			"--dockerfile=/workspace/Dockerfile",
			"--destination=" + destination,
			"--insecure",
			"--insecure-registry=" + registry,
			"--skip-tls-verify-registry=" + registry,
			"--build-arg=ENABLE_CUDA=" + fmt.Sprintf("%t", enableCuda),
			"--build-arg=REGISTRY=" + registry,
		})
	
	// Execute the build
	output, err := kaniko.Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("kaniko build failed: %w", err)
	}
	
	return fmt.Sprintf("Successfully built image: %s\nOutput: %s", destination, output), nil
}

// GetDaggerBuildCommand returns the equivalent dagger command for the old build.sh script
func (m *Test) GetDaggerBuildCommand(
	// Enable CUDA support
	// +default="true"
	enableCuda bool,
	// Service name
	// +default="devenv"
	serviceName string,
	// Image tag
	// +default="v14.0.0"
	imageTag string,
	// Registry URL
	// +default="registry.ra.se:5002"
	registry string,
) string {
	enableCudaStr := "true"
	if !enableCuda {
		enableCudaStr = "false"
	}
	
	return fmt.Sprintf("dagger call build-image --dockerfile-content=\"$(cat Dockerfile)\" --enable-cuda=%s --registry=%s --image-repository=airiksarkivet/%s --image-tag=%s --service-name=%s", 
		enableCudaStr, registry, serviceName, imageTag, serviceName)
}

// Quick builds with common configurations
func (m *Test) BuildCuda(ctx context.Context, dockerfileContent string) (string, error) {
	return m.BuildImage(ctx, dockerfileContent, true, "registry.ra.se:5002", "airiksarkivet/devenv", "v14.0.0", "devenv")
}

func (m *Test) BuildCpu(ctx context.Context, dockerfileContent string) (string, error) {
	return m.BuildImage(ctx, dockerfileContent, false, "registry.ra.se:5002", "airiksarkivet/devenv", "v14.0.0", "devenv")
}

// Test function to verify Dagger connectivity
func (m *Test) Hello() string {
    return "Dagger TCP Success - Build pipeline ready!"
}
