import Foundation
import TildeLabKit

enum LabSidebarSelection: Hashable {
    case research
    case learningLedger
    case modelBenchmarks
    case bench(LabBenchKind)
    case run(UUID)
}
