# xcbuild-parser

A Swift script that parses xcodebuild output and converts it to structured JSON. Supports both XCTest and Swift Testing frameworks, including parameterized tests.

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/xcbuild-parser.git
cd xcbuild-parser

# Make executable
chmod +x xcbuild-parser.swift
```

## Usage

Pipe xcodebuild output to the parser:

```bash
# Parse build and test output
xcodebuild test -scheme "MyScheme" 2>&1 | ./xcbuild-parser.swift

# Include warnings in the output
xcodebuild test -scheme "MyScheme" 2>&1 | ./xcbuild-parser.swift --print-warnings
```

## Output

The parser outputs JSON with the following structure:

```json
{
  "status": "success",
  "summary": {
    "errors": 0,
    "warnings": 2,
    "passedTests": 42,
    "failedTests": 0,
    "buildTime": "12.345"
  },
  "errors": [],
  "warnings": [],
  "testResults": [],
  "xcresultPath": "/path/to/Result.xcresult"
}
```

| Field | Description |
|-------|-------------|
| `status` | `"success"` or `"failure"` |
| `summary` | Aggregate counts and build time |
| `errors` | Array of build errors with file, line, column, and message |
| `warnings` | Array of build warnings (only with `--print-warnings`) |
| `testResults` | Array of failed test results |
| `xcresultPath` | Path to the .xcresult bundle, if available |

## Supported Formats

**Build errors/warnings:**
```
/path/to/file.swift:123:45: error: cannot find 'foo' in scope
```

**XCTest results:**
```
Test Case '-[MyTests testExample]' passed (0.123 seconds).
Test Case '-[MyTests testFailure]' failed (0.456 seconds).
```

**Swift Testing results:**
```
✔ Test "testExample" passed after 0.123 seconds.
✗ Test "testFailure" failed after 0.456 seconds.
✘ Test "paramTest" recorded an issue at file.swift:41:9: assertion failed
```

## License

MIT