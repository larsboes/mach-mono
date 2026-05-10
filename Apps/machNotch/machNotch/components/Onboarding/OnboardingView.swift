//
//  OnboardingView.swift
//  machNotch
//
//  Created by Alexander on 2025-06-23.
//  Modified by Arsh Anwar
//

import SwiftUI
import AVFoundation

enum OnboardingStep {
    case welcome
    case cameraPermission
    case calendarPermission
    case remindersPermission
    case weatherPermission
    case accessibilityPermission
    case musicPermission
    case finished
}

private let calendarService = CalendarDataProvider()

struct OnboardingView: View {
    @State var step: OnboardingStep = .welcome
    @Environment(NotchViewCoordinator.self) var coordinator
    let permissionStore: PermissionStateStore
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    func advanceAfterRequest(_ permission: PermissionType, next: OnboardingStep) async {
        await permissionStore.markRequested(permission)
        withAnimation(.easeInOut(duration: 0.6)) { step = next }
    }

    func checkPermissionAndAdvance(_ permission: PermissionType, next: OnboardingStep) async {
        if await permissionStore.hasRequested(permission) {
            withAnimation(.easeInOut(duration: 0.6)) { step = next }
        } else {
            // Logic to stay on current step to request
        }
    }

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeView {
                    Task {
                        let permissions: [(PermissionType, OnboardingStep)] = [
                            (.camera, .cameraPermission),
                            (.calendar, .calendarPermission),
                            (.reminders, .remindersPermission),
                            (.weather, .weatherPermission),
                            (.accessibility, .accessibilityPermission)
                        ]

                        var nextStep: OnboardingStep = .musicPermission
                        for (perm, s) in permissions.reversed() {
                            if !(await permissionStore.hasRequested(perm)) {
                                nextStep = s
                            }
                        }

                        withAnimation(.easeInOut(duration: 0.6)) { step = nextStep }
                    }
                }                .transition(.opacity)

            case .cameraPermission:
                PermissionRequestView(
                    icon: Image(systemName: "camera.fill"),
                    title: "Enable Camera Access",
                    description: "machNotch includes a mirror feature that lets you quickly check your appearance using your camera, right from the notch. Camera access is required only to show this live preview. You can turn the mirror feature on or off at any time in the app.",
                    privacyNote: "Your camera is never used without your consent, and nothing is recorded or stored.",
                    onAllow: {
                        Task {
                            await requestCameraPermission()
                            await advanceAfterRequest(.camera, next: .calendarPermission)
                        }
                    },
                    onSkip: {
                        Task { await advanceAfterRequest(.camera, next: .calendarPermission) }
                    }
                )
                .transition(.opacity)

            case .calendarPermission:
                PermissionRequestView(
                    icon: Image(systemName: "calendar"),
                    title: "Enable Calendar Access",
                    description: "machNotch can show all your upcoming events in one place. Access to your calendar is needed to display your schedule.",
                    privacyNote: "Your calendar data is only used to show your events and is never shared.",
                    onAllow: {
                        Task {
                            await requestCalendarPermission()
                            await advanceAfterRequest(.calendar, next: .remindersPermission)
                        }
                    },
                    onSkip: {
                        Task { await advanceAfterRequest(.calendar, next: .remindersPermission) }
                    }
                )
                .transition(.opacity)

                case .remindersPermission:
                    PermissionRequestView(
                        icon: Image(systemName: "checklist"),
                        title: "Enable Reminders Access",
                        description: "machNotch can show your scheduled reminders alongside your calendar events. Access to Reminders is needed to display your reminders.",
                        privacyNote: "Your reminders data is only used to show your reminders and is never shared.",
                        onAllow: {
                            Task {
                                await requestRemindersPermission()
                                await advanceAfterRequest(.reminders, next: .weatherPermission)
                            }
                        },
                        onSkip: {
                            Task { await advanceAfterRequest(.reminders, next: .weatherPermission) }
                        }
                    )
                    .transition(.opacity)
                
                case .weatherPermission:
                    PermissionRequestView(
                        icon: Image(systemName: "cloud.sun.fill"),
                        title: "Enable Weather Access",
                        description: "machNotch can display current weather conditions right in the notch. Location access is needed to show weather for your current location.",
                        privacyNote: "Your location is only used to fetch weather data and is never shared or stored.",
                        onAllow: {
                            Task {
                                requestWeatherPermission()
                                await advanceAfterRequest(.weather, next: .accessibilityPermission)
                            }
                        },
                        onSkip: {
                            Task { await advanceAfterRequest(.weather, next: .accessibilityPermission) }
                        }
                    )
                    .transition(.opacity)
                
            case .accessibilityPermission:
                PermissionRequestView(
                    icon: Image(systemName: "hand.raised.fill"),
                    title: "Enable Accessibility Access",
                    description: "Accessibility access is required to replace system notifications with the machNotch HUD. This allows the app to intercept media and brightness events to display custom HUD overlays.",
                    privacyNote: "Accessibility access is used only to improve media and brightness notifications. No data is collected or shared.",
                    onAllow: {
                        Task {
                            await requestAccessibilityPermission()
                            await advanceAfterRequest(.accessibility, next: .musicPermission)
                        }
                    },
                    onSkip: {
                        Task { await advanceAfterRequest(.accessibility, next: .musicPermission) }
                    }
                )
                .transition(.opacity)
                
            case .musicPermission:
                MusicControllerSelectionView(
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            coordinator.firstLaunch = false
                            step = .finished
                        }
                    }
                )
                .transition(.opacity)

            case .finished:
                OnboardingFinishView(onFinish: onFinish, onOpenSettings: onOpenSettings)
            }
        }
        .frame(width: 400, height: 600)
    }

    @Environment(\.pluginManager) var pluginManager
    @Environment(\.xpcHelper) var xpcHelper

    // MARK: - Permission Request Logic

    func requestCameraPermission() async {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func requestCalendarPermission() async {
        _ = try? await calendarService.requestAccess(to: .event)
    }

    func requestRemindersPermission() async {
        _ = try? await calendarService.requestAccess(to: .reminder)
    }
    
    func requestWeatherPermission() {
        pluginManager?.services.weather.checkLocationAuthorization()
    }
    
    func requestAccessibilityPermission() async {
        _ = await xpcHelper?.ensureAccessibilityAuthorization(promptIfNeeded: true)
    }
}
