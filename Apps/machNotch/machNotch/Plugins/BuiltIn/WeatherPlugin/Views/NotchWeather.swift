import SwiftUI

struct WeatherClosedPill: View {
    private enum PopoverMode { case preview, detail }
    let weather: WeatherData
    @Environment(PluginUIContext.self) private var uiContext
    @State private var isHoveringPill = false
    @State private var isHoveringPopover = false
    @State private var popoverMode: PopoverMode = .preview
    @State private var showPopover = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        Button {
            hideTask?.cancel()
            popoverMode = .detail
            withAnimation { showPopover = true }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: weather.systemIconName)
                    .font(.system(size: 12))
                Text(weather.temperatureString)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHoveringPill = hovering
            if hovering {
                uiContext.cancelPendingOpen()
                hideTask?.cancel()
                if !showPopover {
                    popoverMode = .preview
                    withAnimation { showPopover = true }
                }
            } else {
                schedulePreviewHide()
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            popoverContent
                .onHover { hovering in
                    isHoveringPopover = hovering
                    if hovering {
                        hideTask?.cancel()
                    } else {
                        schedulePreviewHide()
                    }
                }
        }
        .onChange(of: showPopover) { _, isShowing in
            uiContext.isBatteryPopoverActive = isShowing
            if !isShowing {
                hideTask?.cancel()
                popoverMode = .preview
            }
        }
        .onDisappear {
            uiContext.isBatteryPopoverActive = false
            hideTask?.cancel()
        }
    }

    @ViewBuilder
    private var popoverContent: some View {
        switch popoverMode {
        case .preview:
            WeatherPreviewCard(weather: weather)
        case .detail:
            WeatherDetailCard(weather: weather)
        }
    }

    private func schedulePreviewHide() {
        guard popoverMode == .preview, !isHoveringPill, !isHoveringPopover else { return }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { showPopover = false } }
        }
    }
}

struct WeatherPreviewCard: View {
    let weather: WeatherData
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WeatherHeader(weather: weather, iconSize: 28, temperatureSize: 22)
            HStack(spacing: 14) {
                WeatherMetric(label: "H/L", value: weather.highLowString)
                WeatherMetric(label: "Humidity", value: "\(weather.humidityInt)%")
                WeatherMetric(label: "Wind", value: weather.windSpeedString)
            }
            WeatherFooter(weather: weather)
        }
        .padding(12)
        .frame(width: 260)
    }
}

struct WeatherDetailCard: View {
    let weather: WeatherData
    var showsChrome = true
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WeatherHeader(weather: weather, iconSize: 42, temperatureSize: 34)
            Divider().background(.white.opacity(0.22))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                WeatherMetric(label: "Feels Like", value: weather.feelsLikeString, icon: "thermometer.medium")
                WeatherMetric(label: "High / Low", value: weather.highLowString, icon: "arrow.up.arrow.down")
                WeatherMetric(label: "Humidity", value: "\(weather.humidityInt)%", icon: "humidity.fill")
                WeatherMetric(label: "Wind", value: weather.windSpeedString, icon: "wind")
                if let chance = weather.precipitationChanceString {
                    WeatherMetric(label: "Rain Chance", value: chance, icon: "cloud.rain.fill")
                }
                if let amount = weather.precipitationAmountString {
                    WeatherMetric(label: "Rain Amount", value: amount, icon: "drop.fill")
                }
                if let uvIndex = weather.uvIndex {
                    WeatherMetric(label: "UV Index", value: "\(uvIndex)", icon: "sun.max.fill")
                }
            }
            WeatherFooter(weather: weather)
        }
        .padding(showsChrome ? 16 : 0)
        .frame(width: showsChrome ? 330 : nil)
        .foregroundStyle(.white)
    }
}

private struct WeatherHeader: View {
    let weather: WeatherData
    let iconSize: CGFloat
    let temperatureSize: CGFloat
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                WeatherConditionAccentView(weather: weather, size: iconSize + 10)
                Image(systemName: weather.systemIconName)
                    .font(.system(size: iconSize))
            }
            .frame(width: iconSize + 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(weather.location)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(weather.condition)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(weather.temperatureString)
                .font(.system(size: temperatureSize, weight: .light, design: .rounded))
        }
    }
}

private struct WeatherMetric: View {
    let label: String
    let value: String
    var icon: String?
    var body: some View {
        HStack(spacing: 7) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WeatherFooter: View {
    let weather: WeatherData
    var body: some View {
        HStack {
            Text(weather.source.rawValue)
            Spacer()
            Text(weather.lastUpdated, style: .relative)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

struct WeatherView: View {
    @Environment(PluginUIContext.self) var uiContext
    @Environment(\.pluginManager) var pluginManager
    @Environment(\.settings) var settings
    var body: some View {
        VStack(spacing: 8) {
            if let weatherService = pluginManager?.services.weather {
                if weatherService.isLoading {
                    loadingView
                } else if let error = weatherService.errorMessage {
                    errorView(message: error)
                } else if let weather = weatherService.currentWeather {
                    WeatherDetailCard(weather: weather, showsChrome: false)
                } else {
                    emptyStateView
                }
            } else {
                emptyStateView
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 182)
        .onAppear {
            pluginManager?.services.weather.checkLocationAuthorization()
        }
        .onChange(of: uiContext.notchState) { _, _ in
            if uiContext.notchState == .open {
                pluginManager?.services.weather.fetchWeather()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView().scaleEffect(0.8).tint(.white)
            Text("Loading weather...")
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
                .multilineTextAlignment(.center)

            if pluginManager?.services.weather.locationAuthorizationStatus == .denied {
                Button("Open Settings") {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
                    {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.effectiveAccent(from: settings))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.fill").font(.title).foregroundColor(Color(white: 0.65))
            Text("No weather data")
                .font(.subheadline)
                .foregroundColor(.white)
            Text("Enable location access")
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WeatherMenuBarSummary: View {
    let weather: WeatherData
    var body: some View {
        Label {
            Text("Weather: \(weather.temperatureString), \(weather.condition)")
        } icon: {
            Image(systemName: weather.systemIconName)
        }
    }
}

#Preview {
    WeatherView()
        .frame(width: 330, height: 190)
        .background(.black)
        .environment(PluginUIContext())
}
