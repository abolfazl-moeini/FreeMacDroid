#!/bin/bash
# Test Phase 1: Check that competing USB/MTP claimers are terminated
set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

echo "Running Test Phase 1: Checking for competing processes..."

# Match any competing processes
RUNNING_COMPETITORS=$(pgrep -fil '[M]acDroid|[D]roiderLauncher|[F]reedroid|[A]ndroid File Transfer|[p]tpcamerad' || true)

if [ -n "$RUNNING_COMPETITORS" ]; then
    echo "FAIL [RED]: Competing processes are still running:"
    echo "$RUNNING_COMPETITORS"
    exit 1
else
    echo "PASS [GREEN]: No competing USB/MTP processes found."
    exit 0
fi
