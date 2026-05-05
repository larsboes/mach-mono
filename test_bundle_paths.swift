import Foundation
let b = Bundle.main
print("Bundle path: \(b.bundlePath)")
print("FrameworksPath: \(String(describing: b.frameworksPath))")
print("PrivateFrameworksPath: \(String(describing: b.privateFrameworksPath))")
