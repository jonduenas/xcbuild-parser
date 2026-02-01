---
name: release
description: Create a new release of xcbuild-parser with automatic Homebrew formula update and AI-generated release notes
user-invocable: true
---

# Release Skill for xcbuild-parser

This skill automates the complete release process including Git tagging, GitHub release creation with auto-generated release notes, and Homebrew formula updates.

## Usage

```
/release v0.2.0
/release v1.0.0
```

## Process

When invoked, perform the following steps:

### 1. Parse and Validate Version

- Extract version from arguments (e.g., "v0.2.0")
- Validate format matches `vX.Y.Z` where X, Y, Z are numbers
- If version is missing or invalid, ask the user for the version number

### 2. Pre-Release Checks

- Check git status to see if there are uncommitted changes
- If uncommitted changes exist:
  - Show what's uncommitted
  - Ask user if they want to commit them first or abort
  - If commit: ask for commit message and commit
- Run `swift build` to ensure the code builds successfully
- Test the built executable: `echo "BUILD SUCCEEDED" | .build/debug/xcbuild-parser`
- If build or test fails, stop and report the error

### 3. Check Version Doesn't Already Exist

- Run `git tag -l` and check if the version tag already exists
- If it exists, ask user if they want to:
  - Delete the old tag and continue
  - Use a different version number
  - Abort

### 4. Generate Release Notes

**Find Previous Release:**
- Get all tags sorted by version: `git tag -l --sort=-version:refname`
- The previous release is the most recent tag (first in the list)
- If no previous tags exist, compare against the first commit

**Analyze Changes:**
- Get commit log since previous release: `git log <previous-tag>..HEAD --oneline`
- Get detailed diff: `git diff <previous-tag>..HEAD`
- Read the commit messages and code changes

**Write Release Notes:**
- Analyze the commits and changes to understand what was added, fixed, or changed
- Categorize changes into:
  - **New Features** - New functionality added
  - **Bug Fixes** - Bugs that were fixed
  - **Improvements** - Enhancements to existing features
  - **Documentation** - Documentation updates
  - **Internal Changes** - Refactoring, dependency updates (only if significant)
- Write concise, user-focused descriptions (not just commit messages)
- Use professional, clean markdown formatting
- Show the generated release notes to the user
- Ask if they want to edit or approve them

**Example format:**
```markdown
## New Features
- Added support for Swift Testing parameterized tests
- Extract .xcresult bundle path from xcodebuild output

## Bug Fixes
- Fixed regex pattern for parsing warnings with special characters

## Improvements
- Improved error messages for build failures
```

### 5. Create Git Tag and Push

- Create the git tag: `git tag <version>`
- Push to GitHub: `git push origin main --tags`

### 6. Create GitHub Release

- Create release with the generated release notes:
  ```bash
  gh release create <version> --title "<version>" --notes "<generated-notes>"
  ```

### 7. Generate SHA256 Hash

- Download the release tarball and compute SHA256:
  ```bash
  curl -sL https://github.com/jonduenas/xcbuild-parser/archive/refs/tags/<version>.tar.gz | shasum -a 256
  ```
- Extract just the hash (first field)
- Show the hash to the user

### 8. Update Homebrew Formula

- Check if `homebrew-tap` directory exists locally
  - If not, ask if they want to clone it to `../homebrew-tap` or provide a path
- Navigate to the homebrew-tap directory
- Update `Formula/xcbuild-parser.rb`:
  - Update the `url` line with new version
  - Update the `sha256` line with new hash
- Show the diff to the user
- Ask for confirmation before committing

### 9. Push Homebrew Formula Update

- Commit the formula: `git commit -m "Update xcbuild-parser to <version>"`
- Push: `git push origin main`

### 10. Verify Installation (Optional)

- Ask user if they want to test the Homebrew installation
- If yes:
  - `brew uninstall xcbuild-parser` (ignore errors if not installed)
  - `brew update`
  - `brew install jonduenas/tap/xcbuild-parser`
  - Test: `echo "BUILD SUCCEEDED" | xcbuild-parser`
  - Show the output

### 11. Success Summary

Display a summary:
```
Release <version> complete!

Created:
  - Git tag: <version>
  - GitHub release: <url>
  - Homebrew formula updated

Users can now install with:
  brew upgrade xcbuild-parser
```

## Error Handling

- If any step fails, stop immediately and show the error
- Always show the command that failed
- Provide suggestions for common errors:
  - Authentication failures: "Run `gh auth login` or check SSH keys"
  - Build failures: "Fix the build errors and try again"
  - Formula update failures: "Check homebrew-tap repository location"

## Safety Features

- Always show git diffs before committing
- Ask for confirmation before pushing
- Validate version format
- Test builds before tagging
- Allow user to review and edit generated release notes
- Allow user to abort at any step
