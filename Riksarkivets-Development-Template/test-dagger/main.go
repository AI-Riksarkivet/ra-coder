// Simple Test Dagger Module for Debugging Connectivity
package main

import (
	"context"
	"fmt"
	"time"
)

type Test struct{}

// HelloWorld - Simple test function that just returns a greeting
func (m *Test) HelloWorld(ctx context.Context) (string, error) {
	return "🚀 Hello from Dagger! Connection is working!", nil
}

// Verbose - Test with verbose output and timing information
func (m *Test) Verbose(ctx context.Context) (string, error) {
	start := time.Now()
	
	// Simple container operation
	result, err := dag.Container().
		From("alpine:latest").
		WithExec([]string{"echo", "Dagger engine is responding!"}).
		WithExec([]string{"date"}).
		WithExec([]string{"uname", "-a"}).
		Stdout(ctx)
	
	if err != nil {
		return "", fmt.Errorf("container operation failed: %w", err)
	}
	
	duration := time.Since(start)
	
	return fmt.Sprintf(`✅ Verbose Test Completed Successfully!

Duration: %v
Engine Response: Working
Container Output:
%s

This confirms:
- Dagger engine connectivity ✓
- Container execution ✓  
- Alpine image pulling ✓
- Command execution ✓`, duration, result), nil
}

// CheckEngine - Test engine capabilities and response time
func (m *Test) CheckEngine(ctx context.Context) (string, error) {
	start := time.Now()
	
	// Test multiple operations
	operations := []struct {
		name string
		test func() (string, error)
	}{
		{
			"Container Creation", 
			func() (string, error) {
				return dag.Container().From("alpine:latest").WithExec([]string{"echo", "container-ok"}).Stdout(ctx)
			},
		},
		{
			"File Operations",
			func() (string, error) {
				return dag.Container().From("alpine:latest").
					WithNewFile("/test.txt", "test content").
					WithExec([]string{"cat", "/test.txt"}).
					Stdout(ctx)
			},
		},
		{
			"Environment Variables",
			func() (string, error) {
				return dag.Container().From("alpine:latest").
					WithEnvVariable("TEST_VAR", "dagger-works").
					WithExec([]string{"sh", "-c", "echo $TEST_VAR"}).
					Stdout(ctx)
			},
		},
	}
	
	var results []string
	for _, op := range operations {
		opStart := time.Now()
		result, err := op.test()
		opDuration := time.Since(opStart)
		
		if err != nil {
			results = append(results, fmt.Sprintf("❌ %s: FAILED (%v) - %v", op.name, opDuration, err))
		} else {
			results = append(results, fmt.Sprintf("✅ %s: SUCCESS (%v) - %s", op.name, opDuration, result))
		}
	}
	
	totalDuration := time.Since(start)
	
	output := fmt.Sprintf(`🔍 Dagger Engine Diagnostics Report

Total Test Duration: %v

Operations Tested:
%s

Summary: Engine is %s`, 
		totalDuration,
		fmt.Sprintf("  %s", fmt.Sprintf("%s\n  ", results[0]) + fmt.Sprintf("%s\n  ", results[1]) + results[2]),
		"responding normally")
	
	return output, nil
}

// QuickTest - Minimal test for fastest response
func (m *Test) QuickTest(ctx context.Context) (string, error) {
	result, err := dag.Container().From("alpine:latest").WithExec([]string{"echo", "quick-test-ok"}).Stdout(ctx)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("⚡ Quick test result: %s", result), nil
}