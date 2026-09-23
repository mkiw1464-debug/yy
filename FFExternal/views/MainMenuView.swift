import SwiftUI

// MARK: - App State

class FFAppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var exploitRunning = false
    @Published var ffInjected    = false
    @Published var ffMaxInjected = false

    private var autoRunDone = false

    var isSupported: Bool {
        if case .unsupported = exploitStatus { return false }
        return true
    }

    func boot() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major, minor: v.minor, patch: v.patch, build: AppInfo.osBuild
        )
        if !supported {
            exploitStatus = .unsupported("iOS \(AppInfo.osVersion)")
            return
        }
        if KernelExploit.requiresSandboxEscape && KernelExploit.hasSandboxAccess() {
            exploitStatus = .success(method: "kexploit")
            return
        }
        if !autoRunDone { autoRunDone = true; runExploit() }
    }

    func runExploit() {
        guard !exploitRunning, !exploitStatus.isSuccess else { return }
        exploitRunning = true
        exploitStatus  = .notStarted
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.exploitRunning = false
                self.exploitStatus  = ok
                    ? .success(method: "kexploit")
                    : .failed(method: "kexploit", code: -1)
            }
        }
    }

    func syncInjectedState() {
        ffInjected    = LicenseService.storedKey() != nil &&
            ContainerStore.resolveAppContainerPath(bundleID: FFGame.freeFire.rawValue)
                .map { _ in FFCheatService.hasBackup(bundleID: FFGame.freeFire.rawValue) } ?? false
        ffMaxInjected = LicenseService.storedKey() != nil &&
            ContainerStore.resolveAppContainerPath(bundleID: FFGame.freefireMax.rawValue)
                .map { _ in FFCheatService.hasBackup(bundleID: FFGame.freefireMax.rawValue) } ?? false
    }
}

// MARK: - Main Menu

struct MainMenuView: View {
    @Environment(\.ffLanguage) private var lang
    @StateObject private var state = FFAppState()

    @State private var selectedTab: Int = 0
    @State private var countdown: String = ""
    @State private var showLogoutConfirm        = false
    @State private var showLanguagePicker       = false
    @State private var showDeepCleanConfirm     = false
    @State private var deepCleanResult: String? = nil
    @State private var keyVisible               = false

    // Revalidation ticker — setiap 60 saat check server
    // supaya mid-session ban/delete auto-logout
    @State private var revalidateTick: Int = 0

    let licenseInfo: LicenseInfo
    let onLogout: () -> Void

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            FFBackground()

            VStack(spacing: 0) {
                topBar
                infoCard
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10)
                gameTabBar
                TabView(selection: $selectedTab) {
                    GameMenuView(
                        game: .freeFire,
                        injected: $state.ffInjected,
                        exploitReady: state.exploitStatus.isSuccess
                    ).tag(0)
                    GameMenuView(
                        game: .freefireMax,
                        injected: $state.ffMaxInjected,
                        exploitReady: state.exploitStatus.isSuccess
                    ).tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)

                deepCleanButton
                telegramBanner
            }
        }
        .onAppear {
            state.boot()
            state.syncInjectedState()
            refreshCountdown()
        }
        .onReceive(timer) { _ in
            refreshCountdown()

            // Local expiry check tiap saat
            if let exp = licenseInfo.expiryDate, exp < Date() { onLogout() }

            // Server revalidation setiap 60 saat — tangkap ban/delete
            revalidateTick += 1
            if revalidateTick >= 60 {
                revalidateTick = 0
                Task {
                    let still = await LicenseService.revalidateBackground(key: licenseInfo.key)
                    if !still {
                        await MainActor.run { onLogout() }
                    }
                }
            }
        }
        // Logout confirm
        .alert(lang.t("logout_confirm_title"), isPresented: $showLogoutConfirm) {
            Button(lang.t("logout_confirm_yes"), role: .destructive) { onLogout() }
            Button(lang.t("logout_confirm_cancel"), role: .cancel) {}
        } message: {
            Text(lang.t("logout_confirm_msg"))
        }
        // Deep Clean confirm
        .alert("Deep Clean", isPresented: $showDeepCleanConfirm) {
            Button("Delete", role: .destructive) { doDeepClean() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear Free Fire App Data")
        }
        // Deep Clean result toast
        .alert(deepCleanResult ?? "", isPresented: .init(
            get: { deepCleanResult != nil },
            set: { if !$0 { deepCleanResult = nil } }
        )) {
            Button("OK", role: .cancel) { deepCleanResult = nil }
        }
        // Language picker sheet
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(onContinue: { showLanguagePicker = false })
        }
    }

    private func refreshCountdown() {
        if let exp = licenseInfo.expiryDate {
            countdown = LicenseService.countdownString(from: exp)
        }
    }

    // MARK: - Deep Clean

    private func doDeepClean() {
        let fm = FileManager.default
        let bundleFF    = FFGame.freeFire.bundleID    // "com.dts.freefireth"
        let bundleFFMax = FFGame.freefireMax.bundleID // "com.dts.freefiremax"

        var deleted: [String] = []
        var failed:  [String] = []

        for bundleID in [bundleFF, bundleFFMax] {
            guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
                failed.append(bundleID)
                continue
            }
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            do {
                // Delete contents of the container folder (not the UUID folder itself)
                let contents = try fm.contentsOfDirectory(
                    at: containerURL,
                    includingPropertiesForKeys: nil,
                    options: []
                )
                for item in contents {
                    try? fm.removeItem(at: item)
                }
                deleted.append(bundleID)
                log("deep clean OK: \(bundleID)")
            } catch {
                failed.append(bundleID)
                log("deep clean FAIL: \(bundleID) — \(error.localizedDescription)")
            }
        }

        // Reset injected state
        state.ffInjected    = false
        state.ffMaxInjected = false

        if failed.isEmpty {
            deepCleanResult = "Cleaned successfully."
        } else {
            deepCleanResult = "Done. Failed: \(failed.joined(separator: ", "))"
        }
    }

    // MARK: ── Top Bar ──

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FF External")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(FFTheme.text)
                Text(lang.t("login_subtitle"))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(FFTheme.textSecondary)
            }

            Spacer()

            // Language button
            Button {
                showLanguagePicker = true
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FFTheme.text)
                    .frame(width: 36, height: 36)
                    .background(FFTheme.card)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(FFTheme.glassBorder, lineWidth: 0.8))
            }
            .buttonStyle(.plain)

            // Logout button
            Button {
                showLogoutConfirm = true
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FFTheme.danger)
                    .frame(width: 36, height: 36)
                    .background(FFTheme.danger.opacity(0.12))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(FFTheme.danger.opacity(0.25), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: ── Info Card ──

    private var infoCard: some View {
        VStack(spacing: 0) {

            // ── KEY row ──
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(FFTheme.textSecondary)
                    .frame(width: 18)

                Text("KEY")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(FFTheme.textSecondary)
                    .tracking(0.8)

                Spacer()

                Text(keyVisible
                     ? licenseInfo.key
                     : LicenseService.maskedKey(licenseInfo.key))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(FFTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .truncationMode(.middle)

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { keyVisible.toggle() }
                } label: {
                    Image(systemName: keyVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(FFTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            rowDivider

            // ── IOS VERSION row ──
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 11))
                    .foregroundStyle(FFTheme.textSecondary)
                    .frame(width: 18)

                Text("IOS VERSION")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(FFTheme.textSecondary)
                    .tracking(0.8)

                Spacer()

                Text("iOS \(licenseInfo.iOSVersion)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(FFTheme.text)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            rowDivider

            // ── DEVICE row ──
            HStack(spacing: 8) {
                Image(systemName: "iphone")
                    .font(.system(size: 11))
                    .foregroundStyle(FFTheme.textSecondary)
                    .frame(width: 18)

                Text("DEVICE")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(FFTheme.textSecondary)
                    .tracking(0.8)

                Spacer()

                Text(licenseInfo.iPhoneModel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(FFTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            rowDivider

            // ── STATUS row ──
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(FFTheme.success)
                    .frame(width: 18)

                Text("STATUS")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(FFTheme.textSecondary)
                    .tracking(0.8)

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FFTheme.success)
                    Text("VERIFIED")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(FFTheme.success)
                        .tracking(0.5)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(FFTheme.success.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(FFTheme.success.opacity(0.30), lineWidth: 0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            rowDivider

            // ── EXPIRY row ──
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(expiryColor)
                    .frame(width: 18)

                Text("EXPIRES IN")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(FFTheme.textSecondary)
                    .tracking(0.8)

                Spacer()

                Text(countdown.isEmpty ? licenseInfo.expiresAt : countdown)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(expiryColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: FFTheme.cornerRadius, style: .continuous)
                .fill(FFTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: FFTheme.cornerRadius, style: .continuous)
                        .strokeBorder(FFTheme.glassBorder, lineWidth: 0.8)
                )
        )
    }

    private var rowDivider: some View {
        Rectangle().fill(FFTheme.separator).frame(height: 0.6)
    }

    private var expiryColor: Color {
        guard let exp = licenseInfo.expiryDate else { return FFTheme.textSecondary }
        let r = exp.timeIntervalSince(Date())
        if r < 0       { return FFTheme.danger }
        if r < 86400   { return FFTheme.danger }
        if r < 259200  { return FFTheme.warn }
        return FFTheme.success
    }

    // MARK: ── Game Tab Bar ──

    private var gameTabBar: some View {
        HStack(spacing: 0) {
            ForEach([FFGame.freeFire, FFGame.freefireMax].indices, id: \.self) { i in
                let game: FFGame = i == 0 ? .freeFire : .freefireMax
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        selectedTab = i
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(game.displayName)
                            .font(.system(size: 14, weight: selectedTab == i ? .bold : .regular, design: .rounded))
                            .foregroundStyle(selectedTab == i ? FFTheme.text : FFTheme.textSecondary)
                        Capsule()
                            .fill(selectedTab == i ? FFTheme.text : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(FFTheme.card)
        .overlay(
            Rectangle().fill(FFTheme.separator).frame(height: 0.6),
            alignment: .bottom
        )
    }

    // MARK: ── Deep Clean Button ──

    private var deepCleanButton: some View {
        Button {
            showDeepCleanConfirm = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("DEEP CLEAN")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.5)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(FFTheme.danger)
            .overlay(
                Rectangle().fill(FFTheme.separator).frame(height: 0.6),
                alignment: .top
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: ── Telegram Banner ──

    private var telegramBanner: some View {
        Button {
            if let url = URL(string: "https://t.me/ffexternal") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(FFTheme.textSecondary)
                Text(lang.t("telegram"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(FFTheme.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FFTheme.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(FFTheme.card)
            .overlay(
                Rectangle().fill(FFTheme.separator).frame(height: 0.6),
                alignment: .top
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Game Menu View

struct GameMenuView: View {
    @Environment(\.ffLanguage) private var lang
    let game: FFGame
    @Binding var injected: Bool
    let exploitReady: Bool

    @State private var selectedFeature: FFFeature = .aimBody
    @State private var injecting            = false
    @State private var showTerminal         = false
    @State private var terminalLines:  [String] = []
    @State private var showSuccess          = false
    @State private var showRestoreSuccess   = false
    @State private var errorMessage: String? = nil
    @State private var availability: [FFFeature: Bool] = [:]
    @State private var checkingAvailability = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                featureGrid
                    .padding(.horizontal, 16)
                hintCard
                    .padding(.horizontal, 16)
                actionButtons
                    .padding(.horizontal, 16)

                if let err = errorMessage {
                    Text(err)
                        .font(FFTheme.captionFont)
                        .foregroundStyle(FFTheme.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 16)
        }
        .overlay(
            Group {
                if showTerminal       { terminalOverlay }
                if showSuccess        { successOverlay(text: lang.t("inject_success"),  icon: "checkmark.seal.fill",              color: FFTheme.success) }
                if showRestoreSuccess { successOverlay(text: lang.t("restore_success"), icon: "arrow.uturn.backward.circle.fill", color: FFTheme.warn) }
            }
        )
        .animation(.easeInOut(duration: 0.22), value: errorMessage)
        .task { await checkAvailability() }
    }

    // MARK: ── Feature Grid ──

    private var featureGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(FFFeature.allCases, id: \.self) { feature in
                FeatureCard(
                    feature: feature,
                    isSelected: selectedFeature == feature,
                    available: availability[feature] ?? true,
                    loading: checkingAvailability
                ) {
                    if availability[feature] ?? true {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                            selectedFeature = feature
                        }
                    }
                }
            }
        }
    }

    // MARK: ── Hint Card ──

    private var hintCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(FFTheme.textSecondary)
                .font(.system(size: 13))
                .padding(.top, 1)
            Text(lang.t("inject_hint"))
                .font(FFTheme.captionFont)
                .foregroundStyle(FFTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FFTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: FFTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FFTheme.cornerRadius, style: .continuous)
                .strokeBorder(FFTheme.glassBorder, lineWidth: 0.8)
        )
    }

    // MARK: ── Action Buttons ──

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if !injected {
                FFButton(
                    title: lang.t("inject"),
                    icon: "bolt.fill",
                    action: doInject,
                    isLoading: injecting,
                    isDisabled: injecting || !(availability[selectedFeature] ?? true)
                )
            } else {
                FFButton(
                    title: lang.t("restore"),
                    icon: "arrow.uturn.backward.circle.fill",
                    action: doRestore,
                    isDisabled: injecting,
                    style: .secondary
                )
            }
        }
    }

    // MARK: ── Terminal Overlay ──

    private var terminalOverlay: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 1, green: 0.37, blue: 0.33)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 1, green: 0.73, blue: 0.18)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 0.15, green: 0.78, blue: 0.40)).frame(width: 10, height: 10)
                    Spacer()
                    Text("FF External — Inject")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(terminalLines.indices, id: \.self) { i in
                            Text(terminalLines[i])
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(lineColor(terminalLines[i]))
                        }
                        Text("█")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 180)
                .background(Color.black.opacity(0.9))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(FFTheme.glassBorder, lineWidth: 0.8)
            )
            .padding(.horizontal, 28)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func lineColor(_ line: String) -> Color {
        if line.contains("Success") || line.contains("✓") || line.contains("OK") { return FFTheme.success }
        if line.contains("✗") || line.contains("error") || line.contains("FAIL") { return FFTheme.danger }
        if line.contains("Injecting") || line.contains("Exploiting")             { return FFTheme.accentAlt }
        return .white.opacity(0.70)
    }

    private func successOverlay(text: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(FFTheme.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FFTheme.background.opacity(0.90).ignoresSafeArea())
        .transition(.opacity)
    }

    // MARK: ── Actions ──

    private func doInject() {
        let feature = selectedFeature
        terminalLines = []
        errorMessage  = nil
        withAnimation { showTerminal = true }

        func line(_ s: String) {
            DispatchQueue.main.async { terminalLines.append(s) }
        }

        Task {
            let gameName = game.displayName
            line("Exploiting \(gameName)")
            try? await Task.sleep(for: .milliseconds(400))
            line("Injecting \(feature.displayName)")
            try? await Task.sleep(for: .milliseconds(500))

            do {
                try await FFCheatService.inject(game: game, feature: feature)
                line("Success inject \(feature.displayName)")
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run {
                    withAnimation { showTerminal = false }
                    injected = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation { showSuccess = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation { showSuccess = false }
                        }
                    }
                }
            } catch {
                line("✗ Error: \(error.localizedDescription)")
                try? await Task.sleep(for: .milliseconds(1500))
                await MainActor.run {
                    withAnimation { showTerminal = false }
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func doRestore() {
        errorMessage = nil
        injecting    = true
        Task {
            do {
                try FFCheatService.restore(game: game)
                await MainActor.run {
                    injecting = false
                    injected  = false
                    withAnimation { showRestoreSuccess = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation { showRestoreSuccess = false }
                    }
                }
            } catch {
                await MainActor.run {
                    injecting    = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func checkAvailability() async {
        checkingAvailability = true
        var result: [FFFeature: Bool] = [:]
        await withTaskGroup(of: (FFFeature, Bool).self) { group in
            for feature in FFFeature.allCases {
                group.addTask {
                    let ok = await FFCheatManifest.checkAvailability(game: self.game, feature: feature)
                    return (feature, ok)
                }
            }
            for await (f, ok) in group { result[f] = ok }
        }
        await MainActor.run {
            availability         = result
            checkingAvailability = false
        }
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let feature:    FFFeature
    let isSelected: Bool
    let available:  Bool
    let loading:    Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.15) : FFTheme.cardElevated)
                        .frame(width: 44, height: 44)

                    if loading {
                        ProgressView().controlSize(.mini).tint(FFTheme.textSecondary)
                    } else {
                        Image(systemName: featureIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                !available  ? FFTheme.textTertiary :
                                isSelected  ? FFTheme.text         : FFTheme.textSecondary
                            )
                    }
                }

                Text(feature.displayName)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(
                        !available  ? FFTheme.textTertiary :
                        isSelected  ? FFTheme.text         : FFTheme.textSecondary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if !available && !loading {
                    Text("N/A")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(FFTheme.danger)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.10) : FFTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected
                                    ? Color.white.opacity(0.35)
                                    : FFTheme.glassBorder,
                                lineWidth: isSelected ? 1.2 : 0.8
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .opacity((!available && !loading) ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
    }

    private var featureIcon: String {
        switch feature {
        case .aimBody:     return "figure.stand"
        case .aimNeck:     return "scope"
        case .aimDrag:     return "cursorarrow.motionlines"
        case .magicBullet: return "burst.fill"
        case .aimChest:    return "target"
        case .esp:         return "eye.fill"
        }
    }
}
