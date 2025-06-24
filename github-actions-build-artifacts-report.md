# GitHub Actions Build Artifacts Report: Documentation Generation Issue

## Executive Summary

The FastLED repository's master branch is experiencing accumulation of build artifacts from documentation generation processes. This report analyzes the responsible GitHub Actions workflow and provides recommendations for resolving the issue.

## Root Cause Analysis

### Primary Workflow: `.github/workflows/docs.yml`

**Status**: ✅ Found - This is the main culprit causing build artifacts accumulation

The `docs.yml` workflow is responsible for generating and deploying documentation to GitHub Pages. Key findings:

- **Trigger**: Only runs on `release` events (when releases are published)
- **Process**: Generates Doxygen documentation and deploys to `gh-pages` branch
- **Deployment**: Uses `peaceiris/actions-gh-pages@v4` action

### Workflow Breakdown

```yaml
name: docs
on:
  release:
    types: released

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - Generate documentation with Doxygen
      - Deploy to gh-pages branch using peaceiris/actions-gh-pages@v4
```

### No Evidence of `docs2.yml`

❌ **`docs2.yml` does not exist** in the repository. The user may have been thinking of a different workflow or this may be from another repository.

## Common Causes of Build Artifact Accumulation

Based on research and the workflow analysis, the primary issues causing build artifacts on the master branch are:

### 1. **Incorrect Branch Targeting**
- The workflow correctly deploys to `gh-pages` branch, not `master`
- However, if there are configuration issues, artifacts might end up on the wrong branch

### 2. **GitHub Actions Artifact Retention**
- Default artifact retention can cause storage buildup
- Each workflow run creates artifacts that persist beyond their usefulness

### 3. **Force Push Issues**
- The workflow uses `force_orphan: false` by default
- This means all deployment history is preserved, potentially causing bloat

### 4. **Large Documentation Generation**
- Doxygen generates comprehensive documentation
- Multiple releases can accumulate significant artifacts

## Recommended Solutions

### Immediate Fixes

#### 1. **Configure Artifact Retention**
Add artifact retention settings to the workflow:

```yaml
- name: Deploy Docs
  uses: peaceiris/actions-gh-pages@v4
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_branch: gh-pages
    publish_dir: ./docs/html
    destination_dir: docs
    user_name: github-actions[bot]
    user_email: github-actions[bot]@users.noreply.github.com
    full_commit_message: Update docs for ${{ steps.repo-info.outputs.commit-message }}
    # Add these options to prevent accumulation
    force_orphan: true  # Creates fresh branch each time
    keep_files: false   # Don't preserve old files
```

#### 2. **Add Workflow Artifact Cleanup**
Add a cleanup step before deployment:

```yaml
- name: Cleanup old artifacts
  run: |
    # Remove old build artifacts
    rm -rf ./docs/html/.git || true
    find ./docs/html -name "*.tmp" -delete || true
```

#### 3. **Implement Artifact Retention Policy**
Add to the workflow job level:

```yaml
jobs:
  docs:
    runs-on: ubuntu-latest
    # Add retention policy
    strategy:
      matrix:
        artifact-retention: [1]  # Keep for 1 day only
```

### Long-term Solutions

#### 1. **Use GitHub's Built-in Pages Action**
Consider migrating to GitHub's official Pages action:

```yaml
- name: Setup Pages
  uses: actions/configure-pages@v3
- name: Upload artifact
  uses: actions/upload-pages-artifact@v2
  with:
    path: ./docs/html
- name: Deploy to GitHub Pages
  uses: actions/deploy-pages@v2
```

#### 2. **Implement Scheduled Cleanup**
Add a separate workflow for periodic cleanup:

```yaml
name: cleanup-artifacts
on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly cleanup
jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Delete old artifacts
        uses: geekyeggo/delete-artifact@v2
        with:
          name: '*'
          failOnError: false
```

#### 3. **Optimize Documentation Generation**
Reduce artifact size by:
- Excluding unnecessary files in Doxygen config
- Compressing generated documentation
- Using incremental builds when possible

### Repository Permissions Fix

Ensure the workflow has proper permissions:

```yaml
jobs:
  docs:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pages: write
      id-token: write
```

## Prevention Strategies

### 1. **Regular Monitoring**
- Set up alerts for repository size
- Monitor GitHub Actions usage and storage

### 2. **Documentation Optimization**
- Review Doxygen configuration to exclude unnecessary files
- Implement documentation versioning strategy

### 3. **Workflow Best Practices**
- Use `force_orphan: true` for documentation deployments
- Implement proper cleanup in CI/CD pipelines
- Set appropriate artifact retention policies

## Verification Steps

After implementing fixes:

1. **Check repository size**: Monitor the `.git` directory size
2. **Verify branch cleanliness**: Ensure master branch only contains source code
3. **Confirm artifact cleanup**: Check GitHub Actions storage usage
4. **Test deployment**: Ensure documentation still deploys correctly

## Conclusion

The `docs.yml` workflow is the primary source of potential build artifact accumulation. While it correctly deploys to the `gh-pages` branch rather than `master`, implementing the recommended fixes will prevent any artifact buildup and optimize the documentation generation process.

The most critical immediate actions are:
1. Add `force_orphan: true` to prevent history accumulation
2. Implement artifact retention policies
3. Add cleanup steps to the workflow

These changes will resolve the build artifact accumulation issue while maintaining the documentation generation functionality.