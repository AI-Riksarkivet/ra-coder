package main

import (
	"context"
	"fmt"
)

type OfflineExample struct{}

// HelloWorld simple greeting without external dependencies
func (m *OfflineExample) HelloWorld(ctx context.Context) (string, error) {
	return "🚀 Hello from offline Dagger! No external registries needed!", nil
}

// CreateFile creates a file in Dagger's virtual filesystem
func (m *OfflineExample) CreateFile(ctx context.Context, filename string, content string) (string, error) {
	// Create a directory with the new file
	newDir := dag.Directory().WithNewFile(filename, content)
	
	// Read back the content to verify
	readContent, err := newDir.File(filename).Contents(ctx)
	if err != nil {
		return "", fmt.Errorf("file creation verification failed: %w", err)
	}
	
	return fmt.Sprintf("✅ Created file '%s' (%d bytes):\n%s", 
		filename, len(readContent), readContent), nil
}

// SimpleTest demonstrates basic Dagger functionality without external dependencies
func (m *OfflineExample) SimpleTest(ctx context.Context) (string, error) {
	// Test file creation
	fileTest, err := m.CreateFile(ctx, "test-output.txt", "Hello from Dagger!\nThis works offline!")
	if err != nil {
		return "", fmt.Errorf("file creation failed: %w", err)
	}
	
	return fmt.Sprintf("🎯 Offline Dagger Test Results:\n\n%s\n\n🎉 Test completed successfully!", fileTest), nil
}

// EchoMessage simple echo function
func (m *OfflineExample) EchoMessage(ctx context.Context, message string) (string, error) {
	return fmt.Sprintf("📢 Echo: %s", message), nil
}