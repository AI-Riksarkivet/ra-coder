package main

import (
	"context"
	"fmt"
)

// TestHelmChart verifies the Coder Helm chart is accessible and valid
func (m *Build) TestHelmChart(ctx context.Context) (string, error) {
	fmt.Println("🔍 TESTING CODER HELM CHART ACCESS")
	fmt.Println("=================================")
	
	result, err := dag.Container().
		From("alpine/helm:latest").
		WithExec([]string{"sh", "-c", `
			echo "1. Adding Coder Helm repository..."
			helm repo add coder-v2 https://helm.coder.com/v2
			
			echo ""
			echo "2. Updating Helm repositories..."
			helm repo update
			
			echo ""
			echo "3. Searching for Coder charts..."
			helm search repo coder-v2
			
			echo ""
			echo "4. Showing Coder chart information..."
			helm show chart coder-v2/coder
			
			echo ""
			echo "✅ SUCCESS: Coder Helm chart is accessible and valid!"
		`}).
		Stdout(ctx)
	
	if err != nil {
		return "", fmt.Errorf("Helm chart test failed: %w", err)
	}
	
	return result, nil
}

// TestCoderVersion checks what Coder version would be installed
func (m *Build) TestCoderVersion(ctx context.Context) (string, error) {
	fmt.Println("📋 CHECKING AVAILABLE CODER VERSIONS")
	fmt.Println("===================================")
	
	result, err := dag.Container().
		From("alpine/helm:latest").
		WithExec([]string{"sh", "-c", `
			helm repo add coder-v2 https://helm.coder.com/v2
			helm repo update
			
			echo "Available Coder versions:"
			helm search repo coder-v2/coder --versions | head -10
			
			echo ""
			echo "Chart details for version 2.25.0:"
			helm show chart coder-v2/coder --version=2.25.0
		`}).
		Stdout(ctx)
	
	if err != nil {
		return "", fmt.Errorf("Version check failed: %w", err)
	}
	
	return result, nil
}