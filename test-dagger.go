package main

import (
	"context"
	"fmt"
	"log"

	"dagger.io/dagger"
)

func main() {
	ctx := context.Background()

	// Initialize Dagger client
	client, err := dagger.Connect(ctx, dagger.WithLogOutput(nil))
	if err != nil {
		log.Fatalf("Failed to connect to Dagger: %v", err)
	}
	defer client.Close()

	fmt.Println("Testing basic container creation...")
	
	// Test basic container creation
	container := client.Container().From("python:3.11-slim")

	fmt.Println("Testing command execution...")
	
	// Test command execution
	result, err := container.WithExec([]string{"python", "--version"}).Stdout(ctx)
	if err != nil {
		log.Fatalf("Failed to execute command: %v", err)
	}
	fmt.Printf("Python version: %s", result)

	fmt.Println("Testing file operations...")
	
	// Test file operations
	containerWithFile := container.WithNewFile("/hello.py", "print('Hello from Dagger!')")
	output, err := containerWithFile.WithExec([]string{"python", "/hello.py"}).Stdout(ctx)
	if err != nil {
		log.Fatalf("Failed to execute script: %v", err)
	}
	fmt.Printf("Script output: %s", output)

	fmt.Println("✅ All Dagger tests passed!")
}