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
		log.Fatal(err)
	}
	defer client.Close()
	
	fmt.Println("🚀 Running offline Dagger example...")
	
	// Example 1: Working with host directory (no external images needed)
	fmt.Println("📁 Testing host directory operations...")
	
	// Mount current directory
	hostDir := client.Host().Directory(".")
	
	// List files in the directory
	entries, err := hostDir.Entries(ctx)
	if err != nil {
		log.Printf("❌ Host directory error: %v", err)
	} else {
		fmt.Printf("✅ Found %d files/directories in current path\n", len(entries))
		for i, entry := range entries {
			if i < 5 { // Show first 5 entries
				fmt.Printf("  - %s\n", entry)
			}
		}
		if len(entries) > 5 {
			fmt.Printf("  ... and %d more\n", len(entries)-5)
		}
	}
	
	// Example 2: Working with files
	fmt.Println("📄 Testing file operations...")
	
	// Try to read a file if it exists
	if fileExists(entries, "go.mod") {
		content, err := hostDir.File("go.mod").Contents(ctx)
		if err != nil {
			log.Printf("❌ File read error: %v", err)
		} else {
			lines := len([]byte(content))
			fmt.Printf("✅ Read go.mod file (%d bytes)\n", lines)
		}
	}
	
	// Example 3: Create a simple file
	fmt.Println("✏️  Testing file creation...")
	
	newFile := client.Directory().
		WithNewFile("test-output.txt", "Hello from Dagger!\nThis file was created without external dependencies.\n")
	
	content, err := newFile.File("test-output.txt").Contents(ctx)
	if err != nil {
		log.Printf("❌ File creation error: %v", err)
	} else {
		fmt.Printf("✅ Created and read test file:\n%s", content)
	}
	
	fmt.Println("🎉 Offline Dagger example completed successfully!")
	fmt.Println("✨ This example works without external registry access")
}

func fileExists(entries []string, filename string) bool {
	for _, entry := range entries {
		if entry == filename {
			return true
		}
	}
	return false
}