#!/usr/bin/env python3

import sys
import dagger
import asyncio

async def main():
    async with dagger.Connection() as client:
        # Test basic container creation
        print("Testing basic container creation...")
        container = client.container().from_("python:3.11-slim")
        
        # Test command execution
        print("Testing command execution...")  
        result = await container.with_exec(["python", "--version"]).stdout()
        print(f"Python version: {result.strip()}")
        
        # Test file operations
        print("Testing file operations...")
        container_with_file = container.with_new_file("/hello.py", "print('Hello from Dagger!')")
        output = await container_with_file.with_exec(["python", "/hello.py"]).stdout()
        print(f"Script output: {output.strip()}")
        
        print("✅ All Dagger tests passed!")

if __name__ == "__main__":
    asyncio.run(main())