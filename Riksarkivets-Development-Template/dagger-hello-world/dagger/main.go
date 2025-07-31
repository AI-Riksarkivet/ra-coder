// Dagger Hello World Example
// Demonstrates connection to Kubernetes Dagger engine and Docker-free building

package main

import (
	"context"
	"fmt"
)

type Hello struct{}

// Hello returns a simple greeting message
func (m *Hello) Hello(ctx context.Context) (string, error) {
	return "🎉 Hello from Dagger running in Kubernetes! 🚀", nil
}

// ContainerHello demonstrates basic container operations
func (m *Hello) ContainerHello(ctx context.Context) (string, error) {
	// Create a container and run a simple command
	result, err := dag.Container().
		From("alpine:latest").
		WithExec([]string{"echo", "Hello from Alpine container in Kubernetes Dagger engine!"}).
		Stdout(ctx)
	
	if err != nil {
		return "", fmt.Errorf("container operation failed: %w", err)
	}
	
	return result, nil
}

// BuildExample demonstrates Docker-free image building with Kaniko
// This shows how to eliminate the parameter size limitations from the Argo approach
func (m *Hello) BuildExample(
	ctx context.Context,
	// Git repository source (replaces dockerfileContent parameter)
	source *Directory,
	// +optional
	// +default="registry.ra.se:5002"
	registry string,
	// +optional
	// +default="hello-world"
	repository string,
	// +optional
	// +default="latest"
	tag string,
) (*Container, error) {
	
	imageTag := fmt.Sprintf("%s/%s:%s", registry, repository, tag)
	
	// Use Kaniko for Docker-free building (no Docker daemon needed!)
	return dag.Container().
		From("gcr.io/kaniko-project/executor:latest").
		WithMountedDirectory("/workspace", source).
		WithExec([]string{
			"/kaniko/executor",
			"--context=/workspace",
			"--dockerfile=/workspace/Dockerfile",
			"--destination=" + imageTag,
			"--no-push",  // For demo, don't actually push
			"--tar-path=/tmp/image.tar",
		}), nil
}

// GitSource demonstrates Git integration (eliminates dockerfileContent parameter)
func (m *Hello) GitSource(
	ctx context.Context,
	// Git repository URL
	repo string,
	// +optional
	// +default="main"
	ref string,
) *Directory {
	return dag.Git(repo, GitOpts{Ref: ref}).Tree()
}

// CompleteWorkflow demonstrates the full pipeline replacing Argo workflows
func (m *Hello) CompleteWorkflow(
	ctx context.Context,
	// +default="https://github.com/docker/getting-started"
	repo string,
	// +optional
	// +default="registry.ra.se:5002"
	registry string,
	// +optional  
	// +default="hello-world"
	repository string,
	// +optional
	// +default="demo"
	tag string,
	// +optional
	// +default="main"
	ref string,
) (string, error) {
	
	// Step 1: Get source from Git (replaces dockerfileContent parameter)
	source := m.GitSource(ctx, repo, ref)
	
	// Step 2: Build the image with Kaniko (Docker-free)
	container, err := m.BuildExample(ctx, source, registry, repository, tag)
	if err != nil {
		return "", fmt.Errorf("build failed: %w", err)
	}
	
	// Step 3: Verify the build
	result, err := container.
		WithExec([]string{"ls", "-la", "/tmp/"}).
		Stdout(ctx)
	
	if err != nil {
		return "", fmt.Errorf("verification failed: %w", err)
	}
	
	return fmt.Sprintf("✅ Successfully built %s/%s:%s using Kaniko in Kubernetes!\n\nBuild output:\n%s", 
		registry, repository, tag, result), nil
}

// KubernetesInfo shows information about the Kubernetes environment
func (m *Hello) KubernetesInfo(ctx context.Context) (string, error) {
	// Get some info about the environment
	result, err := dag.Container().
		From("alpine:latest").
		WithExec([]string{"sh", "-c", "echo 'Running in:'; hostname; echo 'Date:'; date"}).
		Stdout(ctx)
	
	if err != nil {
		return "", fmt.Errorf("failed to get environment info: %w", err)
	}
	
	return fmt.Sprintf("🔍 Kubernetes Dagger Engine Environment:\n%s", result), nil
}

// DemoAdvantages shows the advantages of this approach vs traditional Argo
func (m *Hello) DemoAdvantages(ctx context.Context) (string, error) {
	advantages := `
🎯 Dagger + Kubernetes Engine Advantages:

✅ No Docker daemon required - Uses Kaniko for building
✅ No parameter size limits - Git repository handled natively  
✅ Interactive development - Real-time builds from workspace
✅ Shared infrastructure - One engine serves multiple developers
✅ Git integration built-in - No more dockerfileContent parameters
✅ Better error handling - Programmatic control over build process
✅ Persistent cache - Engine cache survives across sessions
✅ Type safety - Compile-time validation prevents runtime errors
✅ No Argo complexity - Direct pipeline execution from workspace

Traditional Argo Problems Solved:
❌ Parameter size limitations → ✅ Direct Git repository access
❌ Security concerns with parameters → ✅ No sensitive data in parameters  
❌ Difficult debugging → ✅ Interactive pipeline execution
❌ No local testing → ✅ Same tools for dev and production
❌ Complex YAML workflows → ✅ Programmable pipelines as code

This approach eliminates the artificial boundary between development and CI/CD!
`
	
	return advantages, nil
}