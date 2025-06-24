# Git Commands to Analyze Build Artifact Accumulation

## 1. Repository Size and Object Analysis

### Get overall repository statistics
```bash
# Show repository size breakdown
git count-objects -vH

# Show detailed object statistics
git count-objects -v

# Check total repository size
du -sh .git/

# Show pack file sizes
ls -lh .git/objects/pack/
```

## 2. Identify Large Objects in History

### Find the largest objects in your repository
```bash
# Find largest objects in the repository (top 20)
git verify-pack -v .git/objects/pack/*.idx | sort -k 3 -nr | head -20

# More detailed analysis of large objects
git verify-pack -v .git/objects/pack/*.idx | sort -k 3 -nr | head -20 | awk '{print $1 " " $3}' | while read sha size; do
    echo "Size: $size, Object: $sha, Type: $(git cat-file -t $sha), File: $(git rev-list --objects --all | grep $sha | cut -d' ' -f2-)"
done
```

### Find large files by name pattern
```bash
# Find all files matching documentation patterns across all history
git log --all --full-history --name-only --pretty=format: | grep -E '\.(html|css|js|png|jpg|gif|svg|pdf)$' | sort | uniq -c | sort -nr | head -20

# Find files with "doc" or "doxygen" in the name
git log --all --full-history --name-only --pretty=format: | grep -i -E '(doc|doxygen|html)' | sort | uniq -c | sort -nr | head -20

# Find specific Doxygen output patterns
git log --all --full-history --name-only --pretty=format: | grep -E '(search/|html/|latex/)' | sort | uniq -c | sort -nr | head -20
```

## 3. Branch-Specific Analysis

### Analyze the gh-pages branch (where docs are deployed)
```bash
# Check if gh-pages branch exists and its size contribution
git show-branch gh-pages 2>/dev/null && echo "gh-pages exists" || echo "gh-pages does not exist"

# If gh-pages exists, analyze its unique objects
git rev-list --objects gh-pages --not master | wc -l

# Show commits on gh-pages that aren't on master
git log --oneline gh-pages --not master | head -20

# Show file sizes on gh-pages branch
git ls-tree -r -l gh-pages | sort -k4 -nr | head -20
```

### Check all branches for documentation artifacts
```bash
# List all branches
git branch -a

# For each branch, check for documentation files
for branch in $(git branch -r | grep -v HEAD); do
    echo "=== Branch: $branch ==="
    git ls-tree -r $branch | grep -E '\.(html|css|js|png|jpg|gif|svg)$' | wc -l
done
```

## 4. Commit History Analysis

### Find commits that added large amounts of data
```bash
# Show commits with the most file changes (likely bulk documentation commits)
git log --all --numstat --pretty=format:'%H %s' | awk '
    /^[0-9a-f]{40}/ { sha=$1; msg=substr($0,42) }
    /^[0-9]+\t[0-9]+\t/ { adds+=$1; dels+=$2; files++ }
    /^$/ { 
        if (adds+dels > 1000) printf "%s\t%d\t%d\t%d\t%s\n", sha, adds, dels, files, msg
        adds=dels=files=0 
    }' | sort -k2 -nr | head -10

# Find commits that mention documentation
git log --all --oneline --grep="doc" --grep="doxygen" --grep="gh-pages" -i | head -20

# Show commit sizes (this might take a while)
git rev-list --all --objects | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | grep '^blob' | sort -k3 -nr | head -20
```

## 5. File Pattern Analysis

### Identify documentation file patterns taking up space
```bash
# Count files by extension across all history
git log --all --name-only --pretty=format: | grep -v '^$' | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -20

# Find directories with the most files in history
git log --all --name-only --pretty=format: | grep -v '^$' | cut -d'/' -f1 | sort | uniq -c | sort -nr | head -20

# Look for common Doxygen output directories
git log --all --name-only --pretty=format: | grep -E '^(docs|html|search|latex)/' | cut -d'/' -f1-2 | sort | uniq -c | sort -nr | head -20
```

## 6. Specific Doxygen Output Detection

### Find Doxygen-specific files
```bash
# Look for typical Doxygen output files
git log --all --name-only --pretty=format: | grep -E '(doxygen|\.tag|search\.js|jquery\.js|navtree\.js|resize\.js)' | sort | uniq -c | sort -nr

# Find HTML files that are likely generated documentation
git log --all --name-only --pretty=format: | grep '\.html$' | head -20 | while read file; do
    echo "=== $file ==="
    git log --oneline --follow -- "$file" | head -3
done

# Look for search index files (common in Doxygen output)
git log --all --name-only --pretty=format: | grep -i search | sort | uniq -c | sort -nr
```

## 7. Recent Documentation Commits

### Find recent commits that might have introduced artifacts
```bash
# Show recent commits with large file additions
git log --since="6 months ago" --stat --oneline | grep -A5 -B1 "files changed.*insertions"

# Find commits that added documentation files recently
git log --since="1 year ago" --name-status --oneline | grep '^A.*\.(html\|css\|js\|png)' | head -20

# Check for automated commits (like from GitHub Actions)
git log --all --oneline --author="github-actions" | head -10
git log --all --oneline | grep -i "docs\|documentation\|doxygen" | head -20
```

## 8. Clean-up Assessment Commands

### Identify what can be cleaned
```bash
# Show unreachable objects
git fsck --unreachable | head -20

# Show dangling objects
git fsck --dangling | head -20

# Check if there are packed refs that might be keeping objects alive
cat .git/packed-refs | grep gh-pages
```

## 9. Size Impact Analysis

### Calculate potential space savings
```bash
# If you have a gh-pages branch, calculate its unique size
if git show-branch gh-pages 2>/dev/null; then
    echo "Objects unique to gh-pages:"
    git rev-list --objects gh-pages --not $(git for-each-ref --format='%(refname)' refs/heads/ | grep -v gh-pages | head -5) | wc -l
fi

# Show which refs are taking up the most space
git for-each-ref --format='%(refname)' | while read ref; do
    size=$(git rev-list --objects $ref | wc -l)
    echo "$size objects in $ref"
done | sort -nr
```

## Usage Instructions

1. **Start with repository size analysis** (commands in section 1)
2. **Identify large objects** (section 2) to see what's consuming space
3. **Check branches** (section 3), especially `gh-pages` if it exists
4. **Analyze commit patterns** (section 4) to find bulk documentation commits
5. **Look for file patterns** (sections 5-6) to identify Doxygen artifacts
6. **Review recent changes** (section 7) to understand recent additions

## Expected Findings

Based on your repository's documentation workflow, you'll likely find:
- Large numbers of `.html`, `.css`, `.js` files in `gh-pages` branch
- Doxygen search index files
- Generated documentation images and assets
- Automated commits from GitHub Actions documentation builds

The `gh-pages` branch is likely the primary culprit for your half-million objects.