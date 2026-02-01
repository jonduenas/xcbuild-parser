import Foundation

/// Represents a build error or warning from xcodebuild output.
///
/// This structure captures compilation errors and warnings with their source location
/// when available, along with the error message.
public struct BuildError: Codable {
    /// The file path where the error occurred, if available
    public let file: String?
    /// The line number where the error occurred, if available
    public let line: Int?
    /// The column number where the error occurred, if available
    public let column: Int?
    /// The error or warning message
    public let message: String
    /// The type of issue: "error" or "warning"
    public let type: String

    public init(file: String?, line: Int?, column: Int?, message: String, type: String) {
        self.file = file
        self.line = line
        self.column = column
        self.message = message
        self.type = type
    }
}

/// Represents the result of a single test case execution.
///
/// This structure captures test execution details including status, duration,
/// and failure information for both XCTest and Swift Testing frameworks.
public struct TestResult: Codable {
    /// The test suite or class name
    public let suite: String
    /// The test case or method name
    public let testCase: String
    /// The test status: "passed" or "failed"
    public let status: String
    /// The duration in seconds, if available
    public let duration: Double?
    /// The failure message, if the test failed
    public let failureMessage: String?
    /// The source file where the failure occurred, if available
    public let file: String?
    /// The line number where the failure occurred, if available
    public let line: Int?

    public init(suite: String, testCase: String, status: String, duration: Double?, failureMessage: String?, file: String?, line: Int?) {
        self.suite = suite
        self.testCase = testCase
        self.status = status
        self.duration = duration
        self.failureMessage = failureMessage
        self.file = file
        self.line = line
    }
}

/// The complete build and test summary output in JSON format.
///
/// This structure represents the final parsed output containing all build errors
/// and test results from an xcodebuild execution.
public struct BuildSummary: Codable {
    /// Overall status: "success" or "failure"
    public let status: String
    /// Aggregate counts and timing information
    public let summary: Summary
    /// All build errors encountered
    public let errors: [BuildError]
    /// All build warnings encountered (only included if --print-warnings flag is used)
    public let warnings: [BuildError]?
    /// Test results (only failed tests are included)
    public let testResults: [TestResult]
    /// Path to the xcresult bundle, if available
    public let xcresultPath: String?

    public init(status: String, summary: Summary, errors: [BuildError], warnings: [BuildError]?, testResults: [TestResult], xcresultPath: String?) {
        self.status = status
        self.summary = summary
        self.errors = errors
        self.warnings = warnings
        self.testResults = testResults
        self.xcresultPath = xcresultPath
    }
}

/// Aggregate statistics for the build and test execution.
public struct Summary: Codable {
    /// Total number of build errors
    public let errors: Int
    /// Total number of build warnings
    public let warnings: Int
    /// Number of test cases that passed
    public let passedTests: Int
    /// Number of test cases that failed
    public let failedTests: Int
    /// Total execution time in seconds (formatted as string)
    public let buildTime: String

    public init(errors: Int, warnings: Int, passedTests: Int, failedTests: Int, buildTime: String) {
        self.errors = errors
        self.warnings = warnings
        self.passedTests = passedTests
        self.failedTests = failedTests
        self.buildTime = buildTime
    }
}
