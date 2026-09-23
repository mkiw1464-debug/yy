import SwiftUI

@main
struct FFExternalApp: App {
    @AppStorage(FFLanguage.storageKey) private var storedLang = FFLanguage.english.rawValue

    init() {
        setupLogCapture()
        log("FFExternal: launching — iOS \(AppInfo.osVersion) (\(AppInfo.osBuild)) \(AppInfo.displayMachineName)")
    }

    private var language: FFLanguage {
        FFLanguage(rawValue: storedLang) ?? .english
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.ffLanguage, language)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root Navigation

private enum AppScreen {
    case languagePicker
    case login
    case validating          // server check sedang jalan selepas fast-restore
    case menu(LicenseInfo)
}

struct RootView: View {
    @AppStorage(FFLanguage.storageKey) private var storedLang = FFLanguage.english.rawValue
    @State private var screen: AppScreen = .languagePicker

    private var language: FFLanguage {
        FFLanguage(rawValue: storedLang) ?? .english
    }

    var body: some View {
        Group {
            switch screen {
            case .languagePicker:
                LanguagePickerView {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                        screen = .login
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .login:
                LoginView { info in
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                        screen = .menu(info)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            // Spinner semasa server validation — cegah akses ke menu
            // kalau key dah banned/deleted/expired
            case .validating:
                ZStack {
                    FFBackground()
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(FFTheme.text)
                        Text("Verifying key…")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(FFTheme.textSecondary)
                    }
                }
                .transition(.opacity)

            case .menu(let info):
                MainMenuView(licenseInfo: info, onLogout: {
                    LicenseService.logout()
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                        screen = .login
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: screenID)
        .environment(\.ffLanguage, language)
        .task {
            await bootSession()
        }
    }

    // MARK: - Session Boot
    //
    // Flow:
    // 1. Tiada stored key → language picker (fresh install)
    // 2. Ada stored key → fast local check untuk skip language picker
    //    kemudian terus validate dengan server
    // 3. Server OK → masuk menu
    // 4. Server reject (ban/delete/expire/mismatch) → logout → login screen
    //
    private func bootSession() async {
        guard LicenseService.storedKey() != nil else {
            // Fresh install — tunjuk language picker (default state, tiada apa perlu dibuat)
            return
        }

        // Fast local check — skip language picker, tunjuk validating spinner
        if let local = LicenseService.restoreSessionLocal() {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                screen = .validating
            }
            // Server re-validation — tangkap ban/delete/expire sebenar
            let info = await LicenseService.restoreSession()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                if let validated = info {
                    screen = .menu(validated)
                } else {
                    // Key rejected by server — force login
                    screen = .login
                }
            }
            _ = local // suppress warning
        } else {
            // Local check failed (expired) — go login
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                screen = .login
            }
        }
    }

    private var screenID: Int {
        switch screen {
        case .languagePicker: return 0
        case .login:          return 1
        case .validating:     return 2
        case .menu:           return 3
        }
    }
}
