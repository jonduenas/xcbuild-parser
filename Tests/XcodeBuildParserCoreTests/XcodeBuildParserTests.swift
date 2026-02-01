import Testing
import Foundation
@testable import XcodeBuildParserCore
import SnapshotTesting
import InlineSnapshotTesting

@Suite("XcodeBuildParser Tests")
struct XcodeBuildParserTests {

    // MARK: - Build Status Tests

    @Test("Build succeeds with no errors")
    func buildSuccess() throws {
        let lines = try loadFixture("build-success.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "success")
        #expect(summary.summary.errors == 0)
        #expect(summary.summary.warnings == 0)
        #expect(summary.errors.isEmpty)
    }

    @Test("Build fails with compilation errors")
    func buildFailure() throws {
        let lines = try loadFixture("build-failure-errors.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "failure")
        #expect(summary.summary.errors == 3) // 2 compilation errors + 1 "** BUILD FAILED **"
        #expect(summary.errors.count == 3)

        // Verify first error
        let firstError = summary.errors[0]
        #expect(firstError.file == "/Users/developer/MyApp/Sources/main.swift")
        #expect(firstError.line == 15)
        #expect(firstError.column == 5)
        #expect(firstError.message == "cannot find 'foo' in scope")
        #expect(firstError.type == "error")

        // Verify second error
        let secondError = summary.errors[1]
        #expect(secondError.file == "/Users/developer/MyApp/Sources/main.swift")
        #expect(secondError.line == 23)
        #expect(secondError.column == 12)
        #expect(secondError.message == "value of type 'String' has no member 'bar'")
        #expect(secondError.type == "error")
    }

    @Test("Build succeeds with warnings")
    func buildWarnings() throws {
        let lines = try loadFixture("build-warnings.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "success")
        #expect(summary.summary.warnings == 2)
        #expect(summary.warnings == nil) // warnings not included by default

        // Test with --print-warnings
        let parserWithWarnings = XcodeBuildParser(printWarnings: true)
        let summaryWithWarnings = parserWithWarnings.parse(lines: lines)

        #expect(summaryWithWarnings.warnings != nil)
        #expect(summaryWithWarnings.warnings?.count == 2)

        let firstWarning = summaryWithWarnings.warnings![0]
        #expect(firstWarning.file == "/Users/developer/MyApp/Sources/Helper.swift")
        #expect(firstWarning.line == 10)
        #expect(firstWarning.column == 9)
        #expect(firstWarning.type == "warning")
        #expect(firstWarning.message.contains("variable 'unused' was never used"))
    }

    // MARK: - XCTest Tests

    @Test("XCTest all pass")
    func xctestPass() throws {
        let lines = try loadFixture("xctest-pass.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "success")
        #expect(summary.summary.passedTests == 2)
        #expect(summary.summary.failedTests == 0)
        #expect(summary.testResults.isEmpty) // Only failed tests included
    }

    @Test("XCTest with failures")
    func xctestFail() throws {
        let lines = try loadFixture("xctest-fail.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "failure")
        #expect(summary.summary.passedTests == 1)
        #expect(summary.summary.failedTests == 1)
        #expect(summary.testResults.count == 1)

        let failedTest = summary.testResults[0]
        #expect(failedTest.suite == "MyAppTests")
        #expect(failedTest.testCase == "testFailure")
        #expect(failedTest.status == "failed")
        #expect(failedTest.duration == 0.002)
    }

    // MARK: - Swift Testing Tests

    @Test("Swift Testing all pass")
    func swiftTestingPass() throws {
        let lines = try loadFixture("swift-testing-pass.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "success")
        #expect(summary.summary.passedTests == 3)
        #expect(summary.summary.failedTests == 0)
        #expect(summary.testResults.isEmpty)
    }

    @Test("Swift Testing with failures")
    func swiftTestingFail() throws {
        let lines = try loadFixture("swift-testing-fail.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "failure")
        #expect(summary.summary.passedTests == 1)
        #expect(summary.summary.failedTests == 1)
        #expect(summary.testResults.count == 1)

        let failedTest = summary.testResults[0]
        #expect(failedTest.suite == "MyAppTests") // Suite extracted from fixture
        #expect(failedTest.testCase == "failingTest")
        #expect(failedTest.status == "failed")
        #expect(failedTest.duration == 0.002)
    }

    @Test("Swift Testing parameterized pass")
    func swiftTestingParameterizedPass() throws {
        let lines = try loadFixture("swift-testing-parameterized-pass.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "success")
        #expect(summary.summary.passedTests == 19)
        #expect(summary.summary.failedTests == 0)
        #expect(summary.testResults.isEmpty)
    }

    @Test("Swift Testing parameterized with failures")
    func swiftTestingParameterizedFail() throws {
        let lines = try loadFixture("swift-testing-parameterized-fail.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "success") // No individual issue lines, so no failures tracked
        #expect(summary.summary.passedTests == 0)
        #expect(summary.summary.failedTests == 0)
        #expect(summary.testResults.isEmpty)
    }

    @Test("Swift Testing individual issues")
    func swiftTestingIssue() throws {
        let lines = try loadFixture("swift-testing-issue.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "failure")
        #expect(summary.summary.failedTests == 2)
        #expect(summary.testResults.count == 2)

        // Verify first issue
        let firstIssue = summary.testResults[0]
        #expect(firstIssue.suite == "MyAppTests") // Suite extracted from fixture
        #expect(firstIssue.testCase == "testValidation")
        #expect(firstIssue.status == "failed")
        #expect(firstIssue.file == "/Users/developer/MyApp/Tests/ValidationTests.swift")
        #expect(firstIssue.line == 41)
        #expect(firstIssue.failureMessage == "Expectation failed")

        // Verify second issue
        let secondIssue = summary.testResults[1]
        #expect(secondIssue.suite == "MyAppTests") // Suite extracted from fixture
        #expect(secondIssue.testCase == "testCalculation")
        #expect(secondIssue.file == "/Users/developer/MyApp/Tests/MathTests.swift")
        #expect(secondIssue.line == 15)
        #expect(secondIssue.failureMessage == "Values were not equal")
    }

    // MARK: - xcresult Path Tests

    @Test("xcresult path extraction")
    func xcresultPath() throws {
        let lines = try loadFixture("xcresult-path.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.xcresultPath != nil)
        #expect(summary.xcresultPath == "/Users/developer/Library/Developer/Xcode/DerivedData/MyApp-abc/Logs/Test/Run-MyAppTests-2024.01.15_10-30-00-+0000.xcresult")
    }

    // MARK: - Full Integration Tests

    @Test("Full test run with mixed results")
    func fullTestRunMixed() throws {
        let lines = try loadFixture("full-test-run-mixed.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        #expect(summary.status == "failure")
        #expect(summary.summary.passedTests == 5) // 1 XCTest + 1 Swift Test + 3 parameterized
        #expect(summary.summary.failedTests == 2) // 1 Swift Test fail + 1 issue
        #expect(summary.summary.warnings == 1)
        #expect(summary.testResults.count == 2) // Only failed tests
        #expect(summary.xcresultPath != nil)
    }

    // MARK: - JSON Output Snapshot Tests

    @Test("Build success JSON output")
    func buildSuccessJSON() throws {
        let lines = try loadFixture("build-success.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        // Verify structure without checking exact build time
        #expect(summary.status == "success")
        #expect(summary.errors.isEmpty)
        #expect(summary.summary.errors == 0)
        #expect(summary.summary.failedTests == 0)
        #expect(summary.summary.passedTests == 0)
    }

    @Test("Build failure JSON output")
    func buildFailureJSON() throws {
        let lines = try loadFixture("build-failure-errors.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        // Verify structure and error details
        #expect(summary.status == "failure")
        #expect(summary.summary.errors == 3) // 2 compilation errors + "** BUILD FAILED **"
        #expect(summary.errors.count == 3)

        // Verify first compilation error
        #expect(summary.errors[0].file == "/Users/developer/MyApp/Sources/main.swift")
        #expect(summary.errors[0].line == 15)
        #expect(summary.errors[0].column == 5)
        #expect(summary.errors[0].message == "cannot find 'foo' in scope")

        // Verify second compilation error
        #expect(summary.errors[1].file == "/Users/developer/MyApp/Sources/main.swift")
        #expect(summary.errors[1].line == 23)
        #expect(summary.errors[1].column == 12)
        #expect(summary.errors[1].message == "value of type 'String' has no member 'bar'")
    }

    @Test("XCTest failure JSON output")
    func xctestFailureJSON() throws {
        let lines = try loadFixture("xctest-fail.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        // Verify structure and test result details
        #expect(summary.status == "failure")
        #expect(summary.summary.errors == 0)
        #expect(summary.summary.failedTests == 1)
        #expect(summary.summary.passedTests == 1)
        #expect(summary.testResults.count == 1)

        // Verify failed test details
        #expect(summary.testResults[0].suite == "MyAppTests")
        #expect(summary.testResults[0].testCase == "testFailure")
        #expect(summary.testResults[0].status == "failed")
        #expect(summary.testResults[0].duration == 0.002)
    }

    @Test("Swift Testing issue JSON output")
    func swiftTestingIssueJSON() throws {
        let lines = try loadFixture("swift-testing-issue.txt")
        let parser = XcodeBuildParser()
        let summary = parser.parse(lines: lines)

        // Verify structure and issue details
        #expect(summary.status == "failure")
        #expect(summary.summary.errors == 0)
        #expect(summary.summary.failedTests == 2)
        #expect(summary.testResults.count == 2)

        // Verify first issue
        #expect(summary.testResults[0].suite == "MyAppTests")
        #expect(summary.testResults[0].testCase == "testValidation")
        #expect(summary.testResults[0].failureMessage == "Expectation failed")
        #expect(summary.testResults[0].file == "/Users/developer/MyApp/Tests/ValidationTests.swift")
        #expect(summary.testResults[0].line == 41)

        // Verify second issue
        #expect(summary.testResults[1].suite == "MyAppTests")
        #expect(summary.testResults[1].testCase == "testCalculation")
        #expect(summary.testResults[1].failureMessage == "Values were not equal")
        #expect(summary.testResults[1].file == "/Users/developer/MyApp/Tests/MathTests.swift")
        #expect(summary.testResults[1].line == 15)
    }
}
