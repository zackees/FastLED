#!/bin/bash

# FastLED Documentation Artifact Analysis Script
# Analyzes "phantom" files that get pulled but don't appear in working directory

set -e

echo "==================================================="
echo "FastLED Documentation Artifact Analysis"
echo "==================================================="
echo ""

# Create output directory for results
OUTPUT_DIR="git_analysis_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "Results will be saved to: $OUTPUT_DIR"
echo ""

# Function to log both to console and file
log_output() {
    local filename="$1"
    shift
    echo "$@" | tee -a "$OUTPUT_DIR/$filename"
}

echo "1. REPOSITORY SIZE AND OBJECT ANALYSIS"
echo "======================================"

log_output "01_repo_size.txt" "Repository size analysis:"
log_output "01_repo_size.txt" "$(git count-objects -vH)"
log_output "01_repo_size.txt" ""
log_output "01_repo_size.txt" "Git directory size:"
log_output "01_repo_size.txt" "$(du -sh .git/)"
log_output "01_repo_size.txt" ""

# Check for loose vs packed objects
log_output "01_repo_size.txt" "Loose objects directory sizes:"
find .git/objects -type d -name "[0-9a-f][0-9a-f]" | while read dir; do
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    count=$(find "$dir" -type f | wc -l)
    echo "$size ($count files) in $dir"
done | sort -hr | head -10 | tee -a "$OUTPUT_DIR/01_repo_size.txt"

echo ""
echo "2. PHANTOM FILE DETECTION"
echo "========================="

# Look for files that exist in git history but not in current branch
log_output "02_phantom_files.txt" "Files in git history but not in current HEAD:"
git log --all --name-only --pretty=format: | grep -v '^$' | sort -u > "$OUTPUT_DIR/all_files_in_history.txt"
git ls-tree -r --name-only HEAD | sort > "$OUTPUT_DIR/files_in_head.txt"

# Find files that are in history but not in current HEAD
comm -23 "$OUTPUT_DIR/all_files_in_history.txt" "$OUTPUT_DIR/files_in_head.txt" > "$OUTPUT_DIR/phantom_files.txt"

phantom_count=$(wc -l < "$OUTPUT_DIR/phantom_files.txt")
log_output "02_phantom_files.txt" "Found $phantom_count files in git history that are not in current HEAD"
log_output "02_phantom_files.txt" ""

# Show top phantom files by pattern
log_output "02_phantom_files.txt" "Top phantom file patterns:"
if [ -s "$OUTPUT_DIR/phantom_files.txt" ]; then
    # Count by extension
    cat "$OUTPUT_DIR/phantom_files.txt" | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -20 | tee -a "$OUTPUT_DIR/02_phantom_files.txt"
    echo "" | tee -a "$OUTPUT_DIR/02_phantom_files.txt"
    
    # Count by directory
    cat "$OUTPUT_DIR/phantom_files.txt" | cut -d'/' -f1 | sort | uniq -c | sort -nr | head -20 | tee -a "$OUTPUT_DIR/02_phantom_files.txt"
    echo "" | tee -a "$OUTPUT_DIR/02_phantom_files.txt"
    
    # Show sample phantom files
    log_output "02_phantom_files.txt" "Sample phantom files:"
    head -20 "$OUTPUT_DIR/phantom_files.txt" | tee -a "$OUTPUT_DIR/02_phantom_files.txt"
fi

echo ""
echo "3. RELEASE-RELATED ANALYSIS"
echo "==========================="

# Find commits that might be related to releases and documentation
log_output "03_release_analysis.txt" "Release and documentation related commits:"
git log --all --oneline --grep="release" --grep="doc" --grep="doxygen" --grep="gh-pages" -i | head -20 | tee -a "$OUTPUT_DIR/03_release_analysis.txt"

echo ""
log_output "03_release_analysis.txt" ""
log_output "03_release_analysis.txt" "Commits by github-actions (automated builds):"
git log --all --oneline --author="github-actions" --since="1 year ago" | head -20 | tee -a "$OUTPUT_DIR/03_release_analysis.txt"

echo ""
log_output "03_release_analysis.txt" ""
log_output "03_release_analysis.txt" "Large commits (likely documentation uploads):"
git log --all --oneline --shortstat --since="1 year ago" | \
awk '/^[a-f0-9]+ / { commit = $0; } 
     /files? changed/ { 
       if ($1 + $4 > 100) print commit "\n" $0 "\n" 
     }' | head -40 | tee -a "$OUTPUT_DIR/03_release_analysis.txt"

echo ""
echo "4. BRANCH AND REF ANALYSIS"
echo "=========================="

log_output "04_branches.txt" "All branches and refs:"
git branch -a | tee -a "$OUTPUT_DIR/04_branches.txt"
echo "" | tee -a "$OUTPUT_DIR/04_branches.txt"

log_output "04_branches.txt" "All refs:"
git for-each-ref --format='%(refname) %(objectname) %(authordate)' | tee -a "$OUTPUT_DIR/04_branches.txt"
echo "" | tee -a "$OUTPUT_DIR/04_branches.txt"

# Check if gh-pages exists and analyze it
if git show-ref --verify --quiet refs/heads/gh-pages || git show-ref --verify --quiet refs/remotes/origin/gh-pages; then
    log_output "04_branches.txt" "gh-pages branch detected - analyzing..."
    
    # Count unique objects in gh-pages
    if git show-ref --verify --quiet refs/remotes/origin/gh-pages; then
        gh_pages_ref="origin/gh-pages"
    else
        gh_pages_ref="gh-pages"
    fi
    
    unique_objects=$(git rev-list --objects $gh_pages_ref --not HEAD 2>/dev/null | wc -l || echo "0")
    log_output "04_branches.txt" "Objects unique to gh-pages: $unique_objects"
    
    # Show what's in gh-pages
    log_output "04_branches.txt" "File count by type in gh-pages:"
    git ls-tree -r --name-only $gh_pages_ref 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -20 | tee -a "$OUTPUT_DIR/04_branches.txt" || echo "Could not analyze gh-pages content" | tee -a "$OUTPUT_DIR/04_branches.txt"
else
    log_output "04_branches.txt" "No gh-pages branch found"
fi

echo ""
echo "5. OBJECT ARCHAEOLOGY"
echo "===================="

# Find objects that exist but aren't referenced by current branches
log_output "05_objects.txt" "Analyzing git objects..."

# Get all objects
git rev-list --all --objects | cut -d' ' -f1 | sort -u > "$OUTPUT_DIR/all_objects.txt"

# Get objects reachable from current branches
git rev-list --objects HEAD | cut -d' ' -f1 | sort -u > "$OUTPUT_DIR/reachable_objects.txt"

# Find unreachable objects
comm -23 "$OUTPUT_DIR/all_objects.txt" "$OUTPUT_DIR/reachable_objects.txt" > "$OUTPUT_DIR/unreachable_objects.txt"

unreachable_count=$(wc -l < "$OUTPUT_DIR/unreachable_objects.txt")
log_output "05_objects.txt" "Found $unreachable_count objects not reachable from HEAD"

# Analyze what these unreachable objects are
log_output "05_objects.txt" "Types of unreachable objects:"
if [ -s "$OUTPUT_DIR/unreachable_objects.txt" ]; then
    head -100 "$OUTPUT_DIR/unreachable_objects.txt" | while read obj; do
        git cat-file -t "$obj" 2>/dev/null || echo "unknown"
    done | sort | uniq -c | sort -nr | tee -a "$OUTPUT_DIR/05_objects.txt"
fi

echo ""
echo "6. FETCH/PULL ANALYSIS"
echo "======================"

# Show what refs would be updated on fetch
log_output "06_fetch_analysis.txt" "Remote refs that might cause phantom downloads:"
git ls-remote origin | tee -a "$OUTPUT_DIR/06_fetch_analysis.txt"
echo "" | tee -a "$OUTPUT_DIR/06_fetch_analysis.txt"

# Check what's different between local and remote refs
log_output "06_fetch_analysis.txt" "Differences between local and remote refs:"
git remote show origin 2>/dev/null | tee -a "$OUTPUT_DIR/06_fetch_analysis.txt" || echo "Could not analyze remote" | tee -a "$OUTPUT_DIR/06_fetch_analysis.txt"

echo ""
echo "7. FILE ADDITION/DELETION PATTERNS"
echo "=================================="

# Find files that were added and then deleted (phantom file pattern)
log_output "07_add_delete_patterns.txt" "Files that were added and then deleted:"

# Look for documentation files that have been deleted
git log --all --name-status --pretty=format: | grep -E '^[AD].*\.(html|css|js|png|jpg|gif|svg)$' | \
    awk '
    /^A/ { added[substr($0,3)]++; }
    /^D/ { deleted[substr($0,3)]++; }
    END { 
        for (file in deleted) {
            if (added[file] > 0) {
                print file " (added " added[file] " times, deleted " deleted[file] " times)"
            }
        }
    }' | head -50 | tee -a "$OUTPUT_DIR/07_add_delete_patterns.txt"

echo ""
echo "8. DOCUMENTATION GENERATION COMMITS"
echo "==================================="

# Find commits that added many documentation files
log_output "08_doc_commits.txt" "Commits that added documentation files:"
git log --all --name-status --oneline --since="2 years ago" | \
    awk '
    /^[a-f0-9]+ / { 
        commit = $0; 
        added_docs = 0; 
    }
    /^A.*\.(html|css|js|png|jpg|gif|svg)$/ { 
        added_docs++; 
    }
    /^$/ { 
        if (added_docs > 10) {
            print commit " (added " added_docs " doc files)"
        }
    }' | head -20 | tee -a "$OUTPUT_DIR/08_doc_commits.txt"

echo ""
echo "9. REFS AND REFLOG ANALYSIS"
echo "============================"

# Check reflog for phantom references
log_output "09_refs_reflog.txt" "Reflog entries that might explain phantom files:"
git reflog --all | grep -i -E "(doc|release|gh-pages|merge)" | head -20 | tee -a "$OUTPUT_DIR/09_refs_reflog.txt"

echo "" | tee -a "$OUTPUT_DIR/09_refs_reflog.txt"
log_output "09_refs_reflog.txt" "Packed refs content:"
if [ -f .git/packed-refs ]; then
    cat .git/packed-refs | tee -a "$OUTPUT_DIR/09_refs_reflog.txt"
else
    echo "No packed-refs file found" | tee -a "$OUTPUT_DIR/09_refs_reflog.txt"
fi

echo ""
echo "10. SUMMARY AND RECOMMENDATIONS"
echo "==============================="

# Generate summary
{
    echo "FASTLED DOCUMENTATION ARTIFACT ANALYSIS SUMMARY"
    echo "=============================================="
    echo ""
    echo "Repository Statistics:"
    echo "- Total objects: $(git count-objects | grep -o '^[0-9]*' | head -1)"
    echo "- Repository size: $(du -sh .git/ | cut -f1)"
    echo "- Phantom files (in history but not HEAD): $phantom_count"
    echo "- Unreachable objects: $unreachable_count"
    echo ""
    
    if [ -s "$OUTPUT_DIR/phantom_files.txt" ]; then
        echo "Top phantom file types:"
        cat "$OUTPUT_DIR/phantom_files.txt" | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -5
        echo ""
    fi
    
    echo "Likely causes of phantom file downloads:"
    echo "1. gh-pages branch with documentation artifacts"
    echo "2. Documentation files added and deleted in git history"
    echo "3. Unreachable objects from documentation builds"
    echo "4. Remote refs containing documentation branches"
    echo ""
    
    echo "Recommendations:"
    echo "- Check if gh-pages branch needs cleanup"
    echo "- Consider running 'git gc --aggressive' to clean unreachable objects"
    echo "- Review GitHub Actions workflow artifact retention"
    echo "- Consider using 'git filter-branch' or 'git filter-repo' for history cleanup"
    
} | tee "$OUTPUT_DIR/10_summary.txt"

echo ""
echo "Analysis complete! Results saved to: $OUTPUT_DIR"
echo ""
echo "Key files to review:"
echo "- 02_phantom_files.txt: Files in history but not in current branch"
echo "- 05_objects.txt: Unreachable objects analysis"
echo "- 08_doc_commits.txt: Commits that added many documentation files"
echo "- 10_summary.txt: Summary and recommendations"
echo ""
echo "To investigate further, check the specific commits identified in 08_doc_commits.txt"
echo "and run: git show <commit-hash> --name-only --stat"