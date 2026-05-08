import Foundation

struct VisiblePageContextRefreshPolicy: Equatable {
    let minimumRefreshInterval: TimeInterval
    let maximumCacheAge: TimeInterval

    init(
        minimumRefreshInterval: TimeInterval = 3,
        maximumCacheAge: TimeInterval = 20
    ) {
        self.minimumRefreshInterval = max(0, minimumRefreshInterval)
        self.maximumCacheAge = max(self.minimumRefreshInterval, maximumCacheAge)
    }

    func shouldRefresh(
        inFlightMatchesKey: Bool,
        matchingCacheAge: TimeInterval?,
        lastAttemptAge: TimeInterval?,
        allowsFreshCacheRefresh: Bool
    ) -> Bool {
        if inFlightMatchesKey {
            return false
        }

        if let matchingCacheAge {
            if matchingCacheAge < minimumRefreshInterval {
                return false
            }

            if !allowsFreshCacheRefresh && matchingCacheAge < maximumCacheAge {
                return false
            }
        }

        if let lastAttemptAge,
           lastAttemptAge < minimumRefreshInterval {
            return false
        }

        return true
    }
}
