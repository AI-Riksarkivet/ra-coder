// Build Module - Replaces build.yaml Argo workflow with Git-based Dagger approach
// Eliminates dockerfileContent parameter size limitations

package main

import (
	"context"
	"fmt"
)

type Build struct{}

// BuildFromGit builds container image from Git repository (replaces dockerfileContent parameter)
// This is the main function that replaces the entire build.yaml workflow
func (m *Build) BuildFromGit(
	ctx context.Context,
	// Git repository URL containing Dockerfile
	gitRepo string,
	// +optional
	// +default="main"
	gitRef string,
	// +optional
	// +default="registry.ra.se:5002"
	registry string,
	// +optional  
	// +default="airiksarkivet/devenv"
	imageRepository string,
	// +optional
	// +default="latest"
	imageTag string,
	// +optional
	// +default=true
	enableCuda bool,
) (string, error) {

	// Get source from Git (eliminates dockerfileContent parameter!)
	source := dag.Git(gitRepo).Branch(gitRef).Tree()
	
	// Build destination tag
	destination := fmt.Sprintf("%s/%s:%s", registry, imageRepository, imageTag)
	
	// Prepare Kaniko arguments (matching original build.yaml)
	args := []string{
		"--context=/workspace",
		"--dockerfile=/workspace/Dockerfile",
		"--destination=" + destination,
		"--insecure",
		"--insecure-registry=" + registry,
		fmt.Sprintf("--build-arg=ENABLE_CUDA=%t", enableCuda),
		"--build-arg=REGISTRY=" + registry,
	}
	
	// Build with Kaniko using Git source (no dockerfileContent needed!)
	result, err := dag.Container().
		From("gcr.io/kaniko-project/executor:latest").
		WithMountedDirectory("/workspace", source).
		WithExec(args).
		Stdout(ctx)
	
	if err != nil {
		return "", fmt.Errorf("kaniko build failed: %w", err)
	}
	
	return fmt.Sprintf(`🚀 Build completed successfully!

Repository: %s (ref: %s)
Destination: %s
CUDA Enabled: %t

Build Output:
%s`, gitRepo, gitRef, destination, enableCuda, result), nil
}

// BuildCurrentRepo builds from the current repository (common use case)
func (m *Build) BuildCurrentRepo(
	ctx context.Context,
	// +optional
	// +default="registry.ra.se:5002"
	registry string,
	// +optional  
	// +default="airiksarkivet/devenv"
	imageRepository string,
	// +optional
	// +default="latest"
	imageTag string,
	// +optional
	// +default=true
	enableCuda bool,
) (string, error) {

	// Use current directory (should be the repo root with Dockerfile)
	source := dag.CurrentModule().Source()
	
	// Build destination tag
	destination := fmt.Sprintf("%s/%s:%s", registry, imageRepository, imageTag)
	
	// Prepare Kaniko arguments
	args := []string{
		"--context=/workspace",
		"--dockerfile=/workspace/Dockerfile",
		"--destination=" + destination,
		"--insecure",
		"--insecure-registry=" + registry,
		fmt.Sprintf("--build-arg=ENABLE_CUDA=%t", enableCuda),
		"--build-arg=REGISTRY=" + registry,
	}
	
	// Build with Kaniko
	result, err := dag.Container().
		From("gcr.io/kaniko-project/executor:latest").
		WithMountedDirectory("/workspace", source).
		WithExec(args).
		Stdout(ctx)
	
	if err != nil {
		return "", fmt.Errorf("kaniko build failed: %w", err)
	}
	
	return fmt.Sprintf(`🚀 Build completed successfully!

Source: Current repository
Destination: %s
CUDA Enabled: %t

Build Output:
%s`, destination, enableCuda, result), nil
}

// ValidateBuild validates the build configuration without actually building
func (m *Build) ValidateBuild(
	ctx context.Context,
	gitRepo string,
	// +optional
	// +default="main"
	gitRef string,
) (string, error) {

	// Check if repository is accessible
	source := dag.Git(gitRepo).Branch(gitRef).Tree()
	
	// Check if Dockerfile exists
	dockerfileExists, err := source.File("Dockerfile").Contents(ctx)
	if err != nil {
		return "", fmt.Errorf("Dockerfile not found in repository %s (ref: %s): %w", gitRepo, gitRef, err)
	}
	
	// Basic validation
	dockerfileSize := len(dockerfileExists)
	
	return fmt.Sprintf(`✅ Build validation successful!

Repository: %s (ref: %s)
Dockerfile found: Yes (%d bytes)
Ready for build: Yes

This eliminates the dockerfileContent parameter size limitations!`, 
		gitRepo, gitRef, dockerfileSize), nil
}

// TestSource checks what files are available in the build context
func (m *Build) TestSource(ctx context.Context) (string, error) {
	// Check current source
	source := dag.CurrentModule().Source().Directory("..")
	
	// List files to debug
	entries, err := source.Entries(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to list entries: %w", err)
	}
	
	return fmt.Sprintf("Files in parent directory: %v", entries), nil
}