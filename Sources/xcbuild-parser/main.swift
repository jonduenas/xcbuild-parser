import XcodeBuildParserCore

@main
struct XcodeBuildParserCLI {
    static func main() {
        let printWarnings = CommandLine.arguments.contains("--print-warnings")
        let parser = XcodeBuildParser(printWarnings: printWarnings)
        parser.parse()
    }
}
