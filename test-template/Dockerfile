# Simple test Dockerfile for CI pipeline testing
FROM alpine:3.18

# Install basic tools
RUN apk add --no-cache \
    bash \
    curl \
    git

# Create a test user
RUN adduser -D -s /bin/bash testuser

# Set working directory
WORKDIR /home/testuser

# Simple health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD echo "Container is healthy" || exit 1

# Switch to test user
USER testuser

# Add hello world script
RUN echo '#!/bin/bash' > /home/testuser/hello.sh && \
    echo 'echo "Hello World from Coder Workspace Pipeline!"' >> /home/testuser/hello.sh && \
    echo 'echo "Container: $(hostname)"' >> /home/testuser/hello.sh && \
    echo 'echo "User: $(whoami)"' >> /home/testuser/hello.sh && \
    echo 'echo "Date: $(date)"' >> /home/testuser/hello.sh && \
    chmod +x /home/testuser/hello.sh

# Simple command - run hello script then bash
CMD ["/bin/bash", "-c", "/home/testuser/hello.sh && sleep 10"]