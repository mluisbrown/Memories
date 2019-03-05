import StoreKit

struct ReviewHelper {
    static private let userDefaults = UserDefaults.standard
    static let appLaunchCountMod3Key = "AppLaunchCountMod3"

    static func registerAppLaunch() {
        let count = userDefaults.integer(forKey: appLaunchCountMod3Key)
        let newCount = (count + 1) % 3
        
        userDefaults.set(newCount, forKey: appLaunchCountMod3Key)
        userDefaults.synchronize()
    }
    
    static func maybePromptForReview() {
        let count = userDefaults.integer(forKey: appLaunchCountMod3Key)
        if count == 0 {
            SKStoreReviewController.requestReview()
        }
    }
}
