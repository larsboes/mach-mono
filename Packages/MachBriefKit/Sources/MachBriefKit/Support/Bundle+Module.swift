import Foundation

extension Bundle {
    static var module: Bundle = {
        let bundleName = "MachBriefKit_MachBriefKit"
        
        let candidates = [
            Bundle.main.resourceURL,
            Bundle(for: BundleDummy.self).resourceURL,
        ]
        
        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        
        return Bundle(for: BundleDummy.self)
    }()
}

private class BundleDummy {}
