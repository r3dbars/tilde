import Foundation

public enum LabBuiltInSuite: String, LabNamedOption {
    case slackReplyGoldV1 = "slack-reply-gold-v1"
    case replyingV2 = "replying-v2"
    case replyingV1 = "replying-v1"

    public var title: String {
        switch self {
        case .slackReplyGoldV1: "Slack Reply Gold V1 · protected curated"
        case .replyingV2: "Improved Reply Quiz V2 · 400 cases"
        case .replyingV1: "Legacy Reply Baseline V1 · 16 cases"
        }
    }

    public var recommendedPartition: LabScenarioPartition {
        switch self {
        case .slackReplyGoldV1: .development
        case .replyingV2: .validation
        case .replyingV1: .all
        }
    }
}

public enum LabScenarioSuiteLoader {
    /// The improved V2 evaluation is the default for every new Lab run.
    public static func builtInReplyingSuite() throws -> LabScenarioSuite {
        try builtIn(.replyingV2)
    }

    public static func builtIn(_ suite: LabBuiltInSuite) throws -> LabScenarioSuite {
        switch suite {
        case .slackReplyGoldV1: try LabSlackReplyGoldSuiteFactory.makeSuite()
        case .replyingV2: try builtInReplyingSuiteV2()
        case .replyingV1: try builtInReplyingSuiteV1()
        }
    }

    public static func builtInReplyingSuiteV2() throws -> LabScenarioSuite {
        try LabReplyingV2SuiteFactory.makeSuite()
    }

    public static func builtInReplyingSuiteV1() throws -> LabScenarioSuite {
        guard let url = Bundle.main.url(forResource: "replying-v1", withExtension: "json")
            ?? Bundle.module.url(
            forResource: "replying-v1",
            withExtension: "json",
            subdirectory: "Fixtures"
        ) ?? Bundle.module.url(forResource: "replying-v1", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try load(from: url)
    }

    public static func load(from url: URL) throws -> LabScenarioSuite {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let suite = try JSONDecoder().decode(LabScenarioSuite.self, from: data)
        return try suite.validated()
    }
}
