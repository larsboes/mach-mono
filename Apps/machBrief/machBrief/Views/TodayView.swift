import SwiftUI
import MachBriefKit

struct TodayView: View {
    @Bindable var viewModel: BriefTodayViewModel
    @State private var moodNote = ""

    var body: some View {
        VStack(spacing: 16) {
            if let entry = viewModel.currentEntry {
                entryCard(entry)
            } else {
                VStack(spacing: 10) {
                    ContentUnavailableView("No entry yet", systemImage: "book.closed")
                        .font(.headline)
                    Button("Generate today's entry") {
                        Task { await viewModel.refresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
            }
            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .task {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private func entryCard(_ entry: BriefEntry) -> some View {
        if entry.sourceID == "word" {
            wordCard(entry)
        } else {
            standardCard(entry)
        }
    }

    private func wordCard(_ entry: BriefEntry) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            cardHeader(entry, tint: Color(red: 0.33, green: 0.50, blue: 0.49))

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title.lowercased())
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.14, green: 0.14, blue: 0.13))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let partOfSpeech = entry.metadata["partOfSpeech"] {
                        vocabPill("(\(partOfSpeech).)")
                    }
                    if let phonetic = entry.metadata["phonetic"] {
                        vocabPill(phonetic)
                    }
                }
            }

            if let body = entry.body {
                Text(body)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.22, green: 0.22, blue: 0.20))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let example = entry.metadata["example"] {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Example")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.40, green: 0.50, blue: 0.48))
                    Text(example)
                        .font(.callout)
                        .foregroundStyle(Color(red: 0.28, green: 0.30, blue: 0.28))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Label("Word of the day", systemImage: "book.closed")
                Spacer()
                Text(viewModel.currentSlot.label)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(red: 0.38, green: 0.45, blue: 0.44))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 0.86),
                    Color(red: 0.79, green: 0.89, blue: 0.87),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
    }

    private func standardCard(_ entry: BriefEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeader(entry, tint: .secondary)
            Text(entry.title)
                .font(.title3.weight(.semibold))
            if let subtitle = entry.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let body = entry.body {
                Text(body)
                    .font(.body)
            }
            if entry.sourceID == "mood" {
                moodControls
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func cardHeader(_ entry: BriefEntry, tint: Color) -> some View {
        HStack {
            Label(viewModel.currentSlot.label, systemImage: BriefSourceRegistry.descriptor(for: entry.sourceID).systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Spacer()
            Button {
                Task { await viewModel.toggleFavorite() }
            } label: {
                Image(systemName: entry.isFavorited ? "star.fill" : "star")
            }
            .buttonStyle(.plain)
            .foregroundStyle(tint)
            .help(entry.isFavorited ? "Unfavorite" : "Favorite")
        }
    }

    private func vocabPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(red: 0.26, green: 0.34, blue: 0.33))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.62), in: Capsule())
    }

    private var moodControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(MoodRating.allCases, id: \.self) { rating in
                    Button(rating.title) {
                        Task { await viewModel.saveMood(rating: rating, note: moodNote) }
                    }
                }
            }
            TextField("Optional note", text: $moodNote)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.top, 6)
    }
}

private extension DailySlot {
    var label: String {
        switch self {
        case .morning: "06:00"
        case .midday: "12:00"
        case .afternoon: "18:00"
        case .evening: "00:00"
        }
    }
}

private extension MoodRating {
    var title: String {
        rawValue.capitalized
    }
}
