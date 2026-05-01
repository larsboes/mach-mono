//
//  DownloadView.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 17/08/24.
//

import Foundation
import SwiftUI

enum Browser {
    case safari
    case chrome
}

struct DownloadFile {
    var name: String
    var size: Int
    var formattedSize: String
    var browser: Browser
}

import Observation

@Observable
@MainActor
class DownloadWatcher {
    var downloadFiles: [DownloadFile] = []
}

struct DownloadArea: View {
    @Environment(DownloadWatcher.self) var watcher

    private var currentDownload: DownloadFile? { watcher.downloadFiles.first }

    var body: some View {
        HStack(alignment: .center) {
            HStack {
                if currentDownload?.browser == .safari {
                    AppIcon(for: "com.apple.safari")
                } else {
                    AppIcon(for: "com.google.Chrome")
                }
                VStack(alignment: .leading) {
                    Text("Download")
                    Text("In progress").font(.system(.footnote)).foregroundStyle(.gray)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                VStack(alignment: .trailing) {
                    Text(currentDownload?.formattedSize ?? "")
                    Text(currentDownload?.name ?? "").font(.caption2).foregroundStyle(.gray)
                }
            }
        }
    }
}
