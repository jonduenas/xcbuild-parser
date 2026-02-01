import Foundation

/// Parses xcodebuild output and converts it to structured JSON.
///
/// This parser reads xcodebuild output line-by-line, extracting build errors,
/// warnings, and test results. It supports both XCTest and Swift Testing frameworks,
/// including parameterized tests.
///
/// Usage:
/// ```bash
/// xcodebuild test -scheme "MyScheme" 2>&1 | xcbuild-parser
/// xcodebuild test -scheme "MyScheme" 2>&1 | xcbuild-parser --print-warnings
/// ```
public class XcodeBuildParser {
    private var errors: [BuildError] = []
    private var warnings: [BuildError] = []
    private var testResults: [TestResult] = []
    private var startTime: Date?
    private var endTime: Date?
    private var xcresultPath: String?
    private let printWarnings: Bool

    public init(printWarnings: Bool = false) {
        self.printWarnings = printWarnings
    }

    /// Parses xcodebuild output from stdin and outputs JSON summary to stdout.
    ///
    /// Reads line-by-line, extracting build errors, warnings, and test results.
    /// Outputs a JSON-formatted summary when parsing is complete or when build/test completion is detected.
    public func parse() {
        var currentTestSuite: String?

        while let line = readLine() {
            if startTime == nil {
                startTime = Date()
            }

            // Parse build errors and warnings
            if let error = parseError(line) {
                if error.type == "error" {
                    errors.append(error)
                } else {
                    warnings.append(error)
                }
            }

            // Parse test suite
            if line.contains("Test Suite '") && line.contains("' started at") {
                let parts = line.components(separatedBy: "'")
                if parts.count >= 2 {
                    currentTestSuite = parts[1]
                }
            }

            // Parse test case results
            let results = parseTestResult(line, suite: currentTestSuite)
            testResults.append(contentsOf: results)

            // Parse xcresult path
            if let path = parseXCResultPath(line) {
                xcresultPath = path
            }

            // Check for completion
            if line.contains("Test session results") || line.contains("BUILD SUCCEEDED") || line.contains("BUILD FAILED") {
                endTime = Date()
            }
        }

        if endTime == nil {
            endTime = Date()
        }

        outputSummary()
    }

    /// Parses lines and returns a build summary (testable interface).
    ///
    /// - Parameter lines: Array of xcodebuild output lines to parse
    /// - Returns: The parsed build summary
    public func parse(lines: [String]) -> BuildSummary {
        // Reset state
        errors = []
        warnings = []
        testResults = []
        startTime = Date()
        endTime = nil
        xcresultPath = nil

        var currentTestSuite: String?

        for line in lines {
            // Parse build errors and warnings
            if let error = parseError(line) {
                if error.type == "error" {
                    errors.append(error)
                } else {
                    warnings.append(error)
                }
            }

            // Parse test suite
            if line.contains("Test Suite '") && line.contains("' started at") {
                let parts = line.components(separatedBy: "'")
                if parts.count >= 2 {
                    currentTestSuite = parts[1]
                }
            }

            // Parse test case results
            let results = parseTestResult(line, suite: currentTestSuite)
            testResults.append(contentsOf: results)

            // Parse xcresult path
            if let path = parseXCResultPath(line) {
                xcresultPath = path
            }

            // Check for completion
            if line.contains("Test session results") || line.contains("BUILD SUCCEEDED") || line.contains("BUILD FAILED") {
                endTime = Date()
            }
        }

        if endTime == nil {
            endTime = Date()
        }

        return buildSummary()
    }

    func parseError(_ line: String) -> BuildError? {
        // Pattern: /path/to/file.swift:123:45: error: message
        // Pattern: /path/to/file.swift:123:45: warning: message
        let pattern = #"^(.+?):(\d+):(\d+):\s+(error|warning):\s+(.+)$"#

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let file = String(line[Range(match.range(at: 1), in: line)!])
            let lineNum = Int(String(line[Range(match.range(at: 2), in: line)!]))
            let column = Int(String(line[Range(match.range(at: 3), in: line)!]))
            let type = String(line[Range(match.range(at: 4), in: line)!])
            let message = String(line[Range(match.range(at: 5), in: line)!])

            return BuildError(
                file: file,
                line: lineNum,
                column: column,
                message: message,
                type: type
            )
        }

        // Check for build failure marker
        if line.contains("** BUILD FAILED **") {
            let message = line.trimmingCharacters(in: .whitespaces)
            return BuildError(file: nil, line: nil, column: nil, message: message, type: "error")
        }

        // Check for tool-specific errors (clang, linker, swift compiler)
        // These are real build errors without file:line:column format
        let toolErrorPatterns = [
            #"^clang: error:"#,
            #"^ld: error:"#,
            #"^swiftc: error:"#,
            #"^error: linker command failed"#,
            #"^error: fatalError"#,
            #"^fatal error:"#,
            #"^xcodebuild: error:"#,
            #"^error: unable to"#,
            #"^error: cannot"#
        ]

        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        for pattern in toolErrorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) != nil {
                return BuildError(file: nil, line: nil, column: nil, message: trimmedLine, type: "error")
            }
        }

        return nil
    }

    /// Parses a line for the xcresult bundle path.
    ///
    /// Matches lines like: `	/path/to/file.xcresult` (with leading tab/whitespace)
    ///
    /// - Parameter line: The line of output to parse
    /// - Returns: The xcresult path if found, nil otherwise
    func parseXCResultPath(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        guard trimmed.hasSuffix(".xcresult") else {
            return nil
        }

        guard trimmed.hasPrefix("/") else {
            return nil
        }

        return trimmed
    }

    /// Parses a line of xcodebuild output for test results.
    ///
    /// - Parameters:
    ///   - line: The line of output to parse
    ///   - suite: The current test suite name, if available
    /// - Returns: An array of test results found in the line, or empty array if no results found
    func parseTestResult(_ line: String, suite: String?) -> [TestResult] {
        if let results = parseSwiftTestingIssue(line, suite: suite) {
            return results
        }

        if let results = parseSwiftTestingSuccess(line, suite: suite) {
            return results
        }

        if let results = parseSwiftTestingFailure(line, suite: suite) {
            return results
        }

        if let results = parseXCTestResult(line) {
            return results
        }

        return []
    }

    /// Parses Swift Testing parameterized test failure lines.
    ///
    /// Matches lines like: `✘ Test "testName" recorded an issue with 1 argument ... at file.swift:41:9: message`
    ///
    /// - Parameters:
    ///   - line: The line of output to parse
    ///   - suite: The current test suite name, if available
    /// - Returns: An array with a single test result if the line matches, nil otherwise
    func parseSwiftTestingIssue(_ line: String, suite: String?) -> [TestResult]? {
        guard line.contains("✘ Test"), line.contains("recorded an issue") else {
            return nil
        }

        let issuePattern = #"✘ Test "([^"]+)" recorded an issue.*at ([^:]+):(\d+):\d+: (.+)$"#

        guard let regex = try? NSRegularExpression(pattern: issuePattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        let testName = String(line[Range(match.range(at: 1), in: line)!])
        let file = String(line[Range(match.range(at: 2), in: line)!])
        let lineNum = Int(String(line[Range(match.range(at: 3), in: line)!]))
        let message = String(line[Range(match.range(at: 4), in: line)!])

        return [TestResult(
            suite: suite ?? "Swift Testing",
            testCase: testName,
            status: "failed",
            duration: nil,
            failureMessage: message,
            file: file,
            line: lineNum
        )]
    }

    /// Parses Swift Testing success lines, including parameterized tests.
    ///
    /// Matches lines like:
    /// - `✔ Test "testName" passed after 0.123 seconds.`
    /// - `✔ Test "testName" with 19 test cases passed after 0.123 seconds.`
    /// - `✔ Test testName() passed after 0.123 seconds.`
    ///
    /// - Parameters:
    ///   - line: The line of output to parse
    ///   - suite: The current test suite name, if available
    /// - Returns: An array of test results (multiple if parameterized test), nil if line doesn't match
    func parseSwiftTestingSuccess(_ line: String, suite: String?) -> [TestResult]? {
        guard line.contains("✔ Test"), line.contains("passed after") else {
            return nil
        }

        let swiftTestPattern = #"✔ Test (?:"([^"]+)"|(\w+\(\))) (?:with (\d+) test cases )?passed after ([\d.]+) seconds\."#

        guard let regex = try? NSRegularExpression(pattern: swiftTestPattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        var testName = ""
        if let range = Range(match.range(at: 1), in: line), match.range(at: 1).location != NSNotFound {
            testName = String(line[range])
        } else if let range = Range(match.range(at: 2), in: line), match.range(at: 2).location != NSNotFound {
            testName = String(line[range])
        }

        var testCount = 1
        if let countRange = Range(match.range(at: 3), in: line), match.range(at: 3).location != NSNotFound {
            testCount = Int(String(line[countRange])) ?? 1
        }

        let durationRange = Range(match.range(at: 4), in: line)!
        let duration = Double(String(line[durationRange]))

        var results: [TestResult] = []
        for index in 0..<testCount {
            let paramName = testCount > 1 ? "\(testName) [case \(index + 1)]" : testName
            results.append(TestResult(
                suite: suite ?? "Swift Testing",
                testCase: paramName,
                status: "passed",
                duration: duration,
                failureMessage: nil,
                file: nil,
                line: nil
            ))
        }

        return results
    }

    /// Parses Swift Testing failure lines, including parameterized tests.
    ///
    /// Matches lines like:
    /// - `✗ Test "testName" failed after 0.123 seconds.`
    /// - `✘ Test "testName" with X test cases failed after 0.123 seconds with Y issues.`
    ///
    /// Note: Skips summary lines for parameterized tests with individual issue reports
    /// to avoid double-counting failures.
    ///
    /// - Parameters:
    ///   - line: The line of output to parse
    ///   - suite: The current test suite name, if available
    /// - Returns: An array of test results (multiple if parameterized test), nil if line doesn't match, empty array if line should be skipped
    func parseSwiftTestingFailure(_ line: String, suite: String?) -> [TestResult]? {
        guard line.contains("✗ Test") || line.contains("✘ Test"), line.contains("failed after") else {
            return nil
        }

        if line.contains("with"), line.contains("test cases"), line.contains("issues") {
            return []
        }

        let swiftTestFailPattern = #"[✗✘] Test (?:"([^"]+)"|(\w+\(\))) (?:with (\d+) test cases )?failed after ([\d.]+) seconds"#

        guard let regex = try? NSRegularExpression(pattern: swiftTestFailPattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        var testName = ""
        if let range = Range(match.range(at: 1), in: line), match.range(at: 1).location != NSNotFound {
            testName = String(line[range])
        } else if let range = Range(match.range(at: 2), in: line), match.range(at: 2).location != NSNotFound {
            testName = String(line[range])
        }

        var testCount = 1
        if let countRange = Range(match.range(at: 3), in: line), match.range(at: 3).location != NSNotFound {
            testCount = Int(String(line[countRange])) ?? 1
        }

        let durationRange = Range(match.range(at: 4), in: line)!
        let duration = Double(String(line[durationRange]))

        var results: [TestResult] = []
        for index in 0..<testCount {
            let paramName = testCount > 1 ? "\(testName) [case \(index + 1)]" : testName
            results.append(TestResult(
                suite: suite ?? "Swift Testing",
                testCase: paramName,
                status: "failed",
                duration: duration,
                failureMessage: nil,
                file: nil,
                line: nil
            ))
        }

        return results
    }

    /// Parses XCTest result lines for both passing and failing tests.
    ///
    /// Matches lines like:
    /// - `Test Case '-[SuiteTests testName]' passed (0.123 seconds).`
    /// - `Test Case '-[SuiteTests testName]' failed (0.123 seconds).`
    ///
    /// - Parameter line: The line of output to parse
    /// - Returns: An array with a single test result if the line matches, nil otherwise
    func parseXCTestResult(_ line: String) -> [TestResult]? {
        let passPattern = #"Test Case '-\[(.+?)\s+(.+?)\]' passed \((\d+\.\d+) seconds\)\."#

        if let regex = try? NSRegularExpression(pattern: passPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let suiteName = String(line[Range(match.range(at: 1), in: line)!])
            let testName = String(line[Range(match.range(at: 2), in: line)!])
            let duration = Double(String(line[Range(match.range(at: 3), in: line)!]))

            return [TestResult(
                suite: suiteName,
                testCase: testName,
                status: "passed",
                duration: duration,
                failureMessage: nil,
                file: nil,
                line: nil
            )]
        }

        let failPattern = #"Test Case '-\[(.+?)\s+(.+?)\]' failed \((\d+\.\d+) seconds\)\."#

        if let regex = try? NSRegularExpression(pattern: failPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let suiteName = String(line[Range(match.range(at: 1), in: line)!])
            let testName = String(line[Range(match.range(at: 2), in: line)!])
            let duration = Double(String(line[Range(match.range(at: 3), in: line)!]))

            return [TestResult(
                suite: suiteName,
                testCase: testName,
                status: "failed",
                duration: duration,
                failureMessage: nil,
                file: nil,
                line: nil
            )]
        }

        return nil
    }

    private func buildSummary() -> BuildSummary {
        let buildTime: String
        if let start = startTime, let end = endTime {
            let duration = end.timeIntervalSince(start)
            buildTime = String(format: "%.3f", duration)
        } else {
            buildTime = "0.000"
        }

        let passedTests = testResults.count(where: { $0.status == "passed" })
        let failedTests = testResults.count(where: { $0.status == "failed" })

        let status = if errors.isEmpty, failedTests == 0 {
            "success"
        } else {
            "failure"
        }

        return BuildSummary(
            status: status,
            summary: Summary(
                errors: errors.count,
                warnings: warnings.count,
                passedTests: passedTests,
                failedTests: failedTests,
                buildTime: buildTime
            ),
            errors: errors,
            warnings: printWarnings ? warnings : nil,
            testResults: testResults.filter { $0.status == "failed" },
            xcresultPath: xcresultPath
        )
    }

    private func outputSummary() {
        let summary = buildSummary()

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let jsonData = try encoder.encode(summary)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                fputs("Error: Failed to convert JSON data to string\n", stderr)
                exit(1)
            }
            print(jsonString)
        } catch {
            fputs("Error: Failed to encode build summary - \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
