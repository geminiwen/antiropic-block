#!/bin/bash
set +x

# Create /tmp/claude directory if it doesn't exist
mkdir -p /tmp/claude

# Get a random line from DEMAND.txt and pass it to claude
RANDOM_LINE=$(sort -R "$(dirname "$0")/DEMAND.txt" | head -n 1)

# Run claude command in /tmp/claude directory
cd /tmp/claude
claude --print "$RANDOM_LINE"
rm -rf /tmp/claude

echo "Claude command executed with random input."
