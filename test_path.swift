import Foundation
let path = "/tmp/machNotch_app_dir/machNotch.app/Contents/Frameworks/MediaRemoteAdapter.framework"
print(FileManager.default.fileExists(atPath: path))
