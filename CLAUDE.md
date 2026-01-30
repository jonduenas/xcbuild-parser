# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

xcbuild-parser is a single-file Swift script that parses xcodebuild output and converts it to structured JSON. It reads from stdin, extracts build errors, warnings, and test results (both XCTest and Swift Testing frameworks), and outputs a JSON summary to stdout.

## Running the Parser

```bash
# Make executable (if needed)
chmod +x xcbuild-parser.swift

# Basic usage - pipe xcodebuild output
xcodebuild test -scheme "MyScheme" 2>&1 | ./xcbuild-parser.swift

# Include warnings in output
xcodebuild test -scheme "MyScheme" 2>&1 | ./xcbuild-parser.swift --print-warnings
```

## Architecture

The codebase is a single Swift script (`xcbuild-parser.swift`) with no external dependencies. Key components:

**Data Models (Codable structs):**
- `BuildError` - Captures errors/warnings with source location (file, line, column)
- `TestResult` - Test execution result with suite, case name, status, duration, failure info
- `BuildSummary` - Top-level JSON output containing all parsed data
- `Summary` - Aggregate counts (errors, warnings, passed/failed tests, build time)

**Parser Class (`XcodeBuildParser`):**
- Reads stdin line-by-line via `readLine()`
- `parseError(_:)` - Extracts build errors/warnings using regex pattern matching
- `parseTestResult(_:suite:)` - Routes to framework-specific parsers
- `parseSwiftTestingIssue/Success/Failure(_:suite:)` - Swift Testing patterns (✔/✗ markers)
- `parseXCTestResult(_:)` - XCTest patterns (`Test Case '-[Suite test]'`)
- `parseXCResultPath(_:)` - Extracts .xcresult bundle path
- `outputSummary()` - Encodes final JSON output

## Output Format

JSON with `status` ("success"/"failure"), `summary` (counts), `errors`, `warnings` (optional), `testResults` (failed only), and `xcresultPath`.

## Testing Changes

Since this is a stdin/stdout parser, test by piping sample xcodebuild output:

```bash
# Create a test input file with sample xcodebuild output, then:
cat test-input.txt | ./xcbuild-parser.swift
```
