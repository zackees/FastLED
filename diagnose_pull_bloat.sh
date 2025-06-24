#!/bin/bash

# FastLED Git Pull Bloat Diagnosis
# Focused script to understand why git pull downloads phantom documentation files

set -e

echo "================================================="
echo "FastLED Git Pull Bloat Diagnosis"
echo "================================================="
echo ""
echo "This script diagnoses why 'git pull' downloads phantom documentation files"
echo "that don't appear in your working directory but bloat your .git folder."
echo ""

# Function to print section headers
section() {
    echo ""
    echo ">>> $1"
    echo "$(printf '=%.0s' {1..50})"
}

section "CURRENT REPOSITORY STATE"

echo "Repository size:"
du -sh .git/
echo ""

echo "Object count:"
git count-objects -v | head -6
echo ""

echo "Current branch and status:"
git branch --show-current
git status --porcelain | head -5 || echo "Working directory clean"
echo ""

section "REMOTE ANALYSIS - What gets fetched during 'git pull'"

echo "All remote refs (what git pull might fetch):"
git ls-remote origin | head -20
echo ""

echo "Looking for documentation-related remote branches:"
git ls-remote origin | grep -E "(gh-pages|docs|doc)" || echo "No obvious documentation branches found"
echo ""

echo "Remote branches vs local branches:"
echo "Remote branches:"
git ls-remote origin | grep "refs/heads" | wc -l
echo "Local branches:"
git branch -r | wc -l
echo ""

section "PHANTOM FILE DETECTION"

echo "Comparing files in git history vs current working directory..."

# Quick phantom file check
total_files_in_history=$(git log --all --name-only --pretty=format: | grep -v '^$' | sort -u | wc -l)
files_in_current_branch=$(git ls-tree -r --name-only HEAD | wc -l)
phantom_files=$((total_files_in_history - files_in_current_branch))

echo "Files in entire git history: $total_files_in_history"
echo "Files in current HEAD: $files_in_current_branch"
echo "Phantom files (in history but not HEAD): $phantom_files"
echo ""

if [ $phantom_files -gt 1000 ]; then
    echo "🚨 HIGH PHANTOM FILE COUNT DETECTED!"
    echo "Analyzing phantom file patterns..."
    
    # Show phantom file patterns
    git log --all --name-only --pretty=format: | grep -v '^$' | sort -u > /tmp/all_files.txt
    git ls-tree -r --name-only HEAD | sort > /tmp/head_files.txt
    
    echo "Top phantom file extensions:"
    comm -23 /tmp/all_files.txt /tmp/head_files.txt | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -10
    echo ""
    
    echo "Top phantom file directories:"
    comm -23 /tmp/all_files.txt /tmp/head_files.txt | cut -d'/' -f1 | sort | uniq -c | sort -nr | head -10
    echo ""
    
    rm -f /tmp/all_files.txt /tmp/head_files.txt
fi

section "FETCH SIMULATION - What would happen on next git pull"

echo "Simulating git fetch (dry run):"
git fetch --dry-run -v 2>&1 | head -10 || echo "Fetch simulation unavailable"
echo ""

echo "Checking for fetch configurations that might cause bloat:"
echo "Current fetch refspec:"
git config --get remote.origin.fetch || echo "Default fetch refspec"
echo ""

echo "Checking for large remote refs:"
git for-each-ref refs/remotes/ --format='%(refname) %(objectname)' | while read ref sha; do
    count=$(git rev-list --count "$sha" 2>/dev/null || echo "0")
    if [ "$count" -gt 1000 ]; then
        echo "Large ref: $ref ($count commits)"
    fi
done
echo ""

section "DOCUMENTATION BUILD DETECTION"

echo "Looking for documentation build commits (automated):"
git log --oneline --author="github-actions" --since="6 months ago" | head -5 || echo "No github-actions commits found"
echo ""

echo "Looking for large commits (potential doc builds):"
git log --oneline --since="6 months ago" --shortstat | \
awk '/^[a-f0-9]+/ { commit = $0 } 
     /files changed/ { if ($1 > 50) print commit " - " $0 }' | head -5
echo ""

echo "Recent commits mentioning documentation:"
git log --oneline --grep="doc" --grep="doxygen" --since="6 months ago" -i | head -5 || echo "No recent doc commits found"
echo ""

section "OBJECT ANALYSIS - Where are the 500k objects?"

echo "Object breakdown:"
git count-objects -v
echo ""

echo "Large packed objects (potential documentation files):"
if [ -f .git/objects/pack/*.idx ]; then
    git verify-pack -v .git/objects/pack/*.idx 2>/dev/null | \
    sort -k 3 -nr | head -10 | \
    while read sha type size rest; do
        echo "Size: $size bytes, Type: $type"
    done
else
    echo "No pack files found"
fi
echo ""

section "BRANCH IMPACT ANALYSIS"

echo "Analyzing branch-specific object counts:"

# Check if gh-pages exists
if git ls-remote --heads origin gh-pages > /dev/null 2>&1; then
    echo "🎯 FOUND: Remote gh-pages branch (likely culprit!)"
    echo "This branch probably contains generated documentation"
    echo ""
    
    # Try to analyze gh-pages without checking it out
    if git show-ref refs/remotes/origin/gh-pages > /dev/null 2>&1; then
        echo "Local gh-pages tracking branch exists"
        unique_objects=$(git rev-list --objects origin/gh-pages --not HEAD | wc -l)
        echo "Objects unique to gh-pages: $unique_objects"
        echo ""
        
        echo "File types in gh-pages:"
        git ls-tree -r --name-only origin/gh-pages | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -10
    else
        echo "gh-pages exists remotely but not tracked locally"
        echo "This means git pull downloads gh-pages objects without showing them!"
    fi
else
    echo "No gh-pages branch found"
fi
echo ""

section "RECOMMENDATIONS"

echo "Based on analysis:"
echo ""

if git ls-remote --heads origin gh-pages > /dev/null 2>&1; then
    echo "🎯 PRIMARY ISSUE: gh-pages branch"
    echo "   - Your git pull downloads gh-pages documentation files"
    echo "   - These files don't appear in your working directory"
    echo "   - But they're stored in .git/objects/ consuming space"
    echo ""
    echo "   SOLUTION OPTIONS:"
    echo "   1. Stop fetching gh-pages:"
    echo "      git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'"
    echo "      git config --add remote.origin.fetch '^refs/heads/gh-pages'"
    echo ""
    echo "   2. Delete local gh-pages tracking:"
    echo "      git branch -d -r origin/gh-pages 2>/dev/null || true"
    echo ""
    echo "   3. Clean up existing objects:"
    echo "      git gc --aggressive --prune=now"
fi

if [ $phantom_files -gt 1000 ]; then
    echo "🔧 SECONDARY ISSUE: High phantom file count"
    echo "   - Many files exist in git history but not in current branch"
    echo "   - Likely from documentation builds that were later cleaned up"
    echo ""
    echo "   SOLUTION:"
    echo "   - Run: git gc --aggressive --prune=now"
    echo "   - Consider history cleanup if problem persists"
fi

echo ""
echo "💡 IMMEDIATE ACTION:"
echo "Run this to see what git pull would download:"
echo "git fetch --dry-run -v"
echo ""
echo "To prevent future bloat, configure git to skip gh-pages:"
echo "git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'"
echo "git config --add remote.origin.fetch '^refs/heads/gh-pages'"

echo ""
echo "Analysis complete! The issue is likely the gh-pages branch containing"
echo "generated documentation that gets fetched during git pull operations."