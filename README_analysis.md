# FastLED Phantom Documentation Analysis

## The Problem

After a FastLED release, `git pull` operations download a large number of documentation files that don't appear in your working directory. You have ~500k objects but can't see where these files are.

## Root Cause Analysis

This is likely caused by:

1. **Ghost `gh-pages` branch**: Documentation gets deployed to `gh-pages` but gets fetched during `git pull`
2. **Phantom objects**: Files added to git history then deleted, but objects remain
3. **Remote refs**: Documentation branches on origin that get fetched but not checked out
4. **Unreachable objects**: Old documentation builds that aren't garbage collected

## Usage

### Run the Complete Analysis

```bash
./analyze_phantom_docs.sh
```

This script will:
- Analyze repository size and object counts
- Identify "phantom files" that exist in git history but not in your current branch
- Find commits that added large amounts of documentation
- Analyze branch and ref structures
- Identify unreachable objects
- Generate comprehensive reports

### Quick Diagnosis Commands

If you just want to quickly check the issue:

```bash
# Check total objects
git count-objects -vH

# See if gh-pages branch exists remotely
git ls-remote origin | grep gh-pages

# Check what gets fetched during pull
git fetch --dry-run -v

# Find phantom files
git log --all --name-only --pretty=format: | sort -u | wc -l
git ls-tree -r --name-only HEAD | wc -l
```

## Expected Output

The script will create a timestamped directory (e.g., `git_analysis_20231201_143022/`) containing:

- `02_phantom_files.txt` - Files in git history but not in current branch
- `04_branches.txt` - Analysis of all branches, especially gh-pages
- `06_fetch_analysis.txt` - What remote refs cause downloads during pull
- `08_doc_commits.txt` - Specific commits that added documentation
- `10_summary.txt` - Summary and recommendations

## Likely Findings

Based on the FastLED repository structure, you'll probably find:

1. **Remote `gh-pages` branch** containing thousands of generated HTML/CSS/JS files
2. **Unreachable objects** from old documentation builds
3. **Documentation commits** that added files then deleted them
4. **Remote refs** being fetched that contain documentation artifacts

## Solutions

Once you identify the source:

### If it's a gh-pages branch:
```bash
# Stop fetching gh-pages
git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'

# Or delete local gh-pages tracking
git branch -d -r origin/gh-pages
```

### If it's unreachable objects:
```bash
# Aggressive garbage collection
git gc --aggressive --prune=now

# Or repack everything
git repack -a -d -f --depth=50 --window=50
```

### If it's phantom history:
```bash
# Use git filter-repo to clean history
# (BACKUP FIRST!)
git filter-repo --invert-paths --path-glob '*.html' --path-glob '*.css' --path-glob '*.js'
```

## Important Notes

- **BACKUP YOUR REPOSITORY** before running cleanup commands
- The script is read-only and safe to run
- Results are saved to timestamped directories for later reference
- Focus on the `gh-pages` branch analysis - that's likely your culprit

## Understanding Git Pull Behavior

`git pull` = `git fetch` + `git merge`

During `git fetch`, Git downloads:
- All objects referenced by remote branches
- All remote refs (including gh-pages if it exists)
- Objects needed to update local remote-tracking branches

Even if you never checkout gh-pages, its objects get downloaded and stored in your `.git/objects/` directory, contributing to your 500k object count.