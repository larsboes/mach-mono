//
//  BriefExpandedView.swift
//  machNotch
//

import MachBriefKit
import SwiftUI

struct BriefExpandedView: View {
    let entries: [String: BriefEntry]
    let sources: [String]
    let languageID: String
    let onLanguageChange: (String) -> Void

    @State private var activeSource: String = "word"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pillBar
            Divider()
                .opacity(0.12)
                .padding(.horizontal, 16)
            contentArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Pill bar

    private var pillBar: some View {
        HStack(spacing: 4) {
            ForEach(sources, id: \.self) { sourceID in
                let descriptor = BriefSourceRegistry.descriptor(for: sourceID)
                let isActive = activeSource == sourceID

                HStack(spacing: 5) {
                    Image(systemName: descriptor.systemImage)
                        .font(.system(size: 11, weight: .medium))
                    Text(descriptor.displayName)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isActive ? .white : Color(white: 0.55))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isActive ? Color(white: 1, opacity: 0.12) : .clear)
                )
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) { activeSource = sourceID }
                    }
                }
                .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isActive)
            }
            Spacer()
            languageToggle
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Language toggle

    private var languageToggle: some View {
        HStack(spacing: 2) {
            ForEach(BriefLanguage.supported) { lang in
                let isActive = languageID == lang.id
                Text(lang.id.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? .white : Color(white: 0.45))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isActive ? Color(white: 1, opacity: 0.12) : .clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onLanguageChange(lang.id) }
                    .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isActive)
            }
        }
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if let entry = entries[activeSource] {
            BriefEntryDetailView(entry: entry)
                .id(activeSource)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Entry detail

private struct BriefEntryDetailView: View {
    let entry: BriefEntry

    var body: some View {
        switch entry.sourceID {
        case "word": wordView
        case "quote": quoteView
        case "mantra": mantraView
        default: genericView
        }
    }

    private var wordView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title.lowercased())
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
            if let subtitle = entry.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.58, blue: 0.55))
            }
            if let body = entry.body, !body.isEmpty {
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
            if let example = entry.metadata["example"] {
                Text(example)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quoteView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\u{201C}\(entry.title)\u{201D}")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(4)
            if let author = entry.subtitle, !author.isEmpty {
                Text("— \(author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mantraView: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(entry.title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    private var genericView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(4)
            if let body = entry.body, !body.isEmpty {
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
