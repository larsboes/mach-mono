//
//  QuickLookServiceProtocol.swift
//  boringNotch
//

import Foundation
import SwiftUI

@MainActor
protocol QuickLookServiceProtocol: AnyObject, Observable {
    var urls: [URL] { get }
    var selectedURL: URL? { get set }
    var isQuickLookOpen: Bool { get }
    
    func show(urls: [URL], selectFirst: Bool, slideshow: Bool)
    func hide()
    func updateSelection(urls: [URL])
}

extension QuickLookServiceProtocol {
    func show(urls: [URL], selectFirst: Bool = true, slideshow: Bool = false) {
        show(urls: urls, selectFirst: selectFirst, slideshow: slideshow)
    }
}
