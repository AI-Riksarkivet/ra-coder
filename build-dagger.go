package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	
	"dagger.io/dagger"
)

func main() {
	// Command line flags
	var (
		enableCuda    = flag.Bool("cuda", true, "Enable CUDA support")
		serviceName   = flag.String("service", "devenv", "Service name")
		tag           = flag.String("tag", "v14.1.2", "Image tag")
		registry      = flag.String("registry", "registry.ra.se:5002", "Container registry")
		gitRef        = flag.String("ref", "main", "Git reference (branch/tag)")
	)
	flag.Parse()

	// Fixed SSH Git repository
	gitRepo := "ssh://git@devops.ra.se:22/DataLab/Datalab/_git/coder-templates"

	fmt.Println("Building with Dagger + Kaniko from SSH Git")
	fmt.Printf("CUDA support: %t\n", *enableCuda)
	fmt.Printf("Service: %s\n", *serviceName)
	fmt.Printf("Tag: %s\n", *tag)
	fmt.Printf("Registry: %s\n", *registry)
	fmt.Printf("Git Repository: %s\n", gitRepo)
	fmt.Printf("Git Reference: %s\n", *gitRef)

	// Set image tag suffix for CPU builds
	imageTag := *tag
	if !*enableCuda {
		imageTag = fmt.Sprintf("%s-cpu", *tag)
	}

	ctx := context.Background()

	// Initialize Dagger client
	client, err := dagger.Connect(ctx, dagger.WithLogOutput(os.Stdout))
	if err != nil {
		log.Fatalf("Failed to connect to Dagger: %v", err)
	}
	defer client.Close()

	fmt.Printf("🚀 Building %s/%s:%s from SSH Git repository...\n", *registry, fmt.Sprintf("airiksarkivet/%s", *serviceName), imageTag)

	// Try to use SSH git repository, fallback to current directory
	fmt.Println("📥 Attempting to clone SSH git repository...")
	
	var src *dagger.Directory
	
	// Check if SSH agent is available
	sshAuthSocket := os.Getenv("SSH_AUTH_SOCK")
	if sshAuthSocket != "" {
		fmt.Println("🔑 Using SSH authentication...")
		src = client.Git(gitRepo, dagger.GitOpts{
			SSHAuthSocket: client.Host().UnixSocket(sshAuthSocket),
		}).Ref(*gitRef).Tree()
	} else {
		fmt.Println("⚠️  SSH agent not available, using current directory as build context")
		src = client.Host().Directory(".")
	}

	// Build with Kaniko
	fmt.Println("🔨 Starting Kaniko build from SSH git source...")

	destination := fmt.Sprintf("%s/airiksarkivet/%s:%s", *registry, *serviceName, imageTag)

	result, err := client.Container().
		From("gcr.io/kaniko-project/executor:latest").
		WithMountedDirectory("/workspace", src).
		WithExec([]string{
			"/kaniko/executor",
			"--context=/workspace/Riksarkivets-Development-Template",
			"--dockerfile=/workspace/Riksarkivets-Development-Template/Dockerfile",
			"--destination=" + destination,
			"--insecure",
			"--insecure-registry=" + *registry,
			"--skip-tls-verify-registry=" + *registry,
			"--build-arg=ENABLE_CUDA=" + fmt.Sprintf("%t", *enableCuda),
			"--build-arg=REGISTRY=" + *registry,
			"--cache=false",
			"--verbosity=info",
		}).
		Stdout(ctx)

	if err != nil {
		log.Fatalf("❌ Build failed: %v", err)
	}

	fmt.Println("✅ Build completed successfully!")
	fmt.Printf("🎯 Final image: %s\n", destination)
	fmt.Printf("📋 Build output:\n%s\n", result)
}