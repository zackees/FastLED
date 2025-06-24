#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <new_branch_name>"
    exit 1
fi

NEW_BRANCH="$1"

# Ensure master is up to date
git checkout master
git pull

# Create an orphan branch with no history
git checkout --orphan "$NEW_BRANCH"

# Remove all tracked files from index (staged area)
git reset --hard

# Copy files from master branch
git checkout master -- .

# Stage all files
git add .

# Commit the files to start new history
git commit -m "Initial commit for $NEW_BRANCH with files from master"

# Inform user
echo "New branch '$NEW_BRANCH' created with files from master and no history."
