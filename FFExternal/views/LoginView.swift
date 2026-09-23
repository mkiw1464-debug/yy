import SwiftUI

struct LoginView: View {
    @Environment(\.ffLanguage) private var lang
    @State private var keyInput: String = ""
    @State private var validating = false
    @State private var error: String? = nil

    let onSuccess: (LicenseInfo) -> Void

    private var supportStatus: IOSSupportStatus {
        let v = AppInfo.versionTuple
        return IOSSupportStatus(
            version: AppInfo.osVersion,
            isSupported: ExploitSupportPolicy.isSupported(
                major: v.major, minor: v.minor, patch: v.patch,
                build: AppInfo.osBuild
            )
        )
    }

    var body: some View {
        ZStack {
            FFBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer(minLength: 64)

                    // ── Header ──
                    VStack(spacing: 12) {
                        Image(systemName: "scope")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundStyle(FFTheme.text)

                        Text(lang.t("login_title"))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(FFTheme.text)

                        Text(lang.t("login_subtitle"))
                            .font(FFTheme.subtitleFont)
                            .foregroundStyle(FFTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // ── License Key Card (single card, no outer wrapper) ──
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang.t("key_label").uppercased())
                            .font(FFTheme.labelFont)
                            .foregroundStyle(FFTheme.textSecondary)
                            .tracking(1.0)

                        // Input field
                        HStack(spacing: 10) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(FFTheme.textSecondary)

                            TextField(lang.t("key_placeholder"), text: $keyInput)
                                .font(FFTheme.monoFont)
                                .foregroundStyle(FFTheme.text)
                                .autocapitalization(.allCharacters)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .tint(FFTheme.text)
                                .placeholder(when: keyInput.isEmpty) {
                                    Text(lang.t("key_placeholder"))
                                        .font(FFTheme.monoFont)
                                        .foregroundStyle(FFTheme.textTertiary)
                                }
                        }
                        .padding(14)
                        .background(FFTheme.cardElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    error != nil
                                        ? FFTheme.danger.opacity(0.6)
                                        : (!keyInput.isEmpty
                                            ? Color.white.opacity(0.25)
                                            : FFTheme.glassBorder),
                                    lineWidth: 1
                                )
                        )

                        // Error
                        if let error {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(FFTheme.danger)
                                Text(error)
                                    .font(FFTheme.captionFont)
                                    .foregroundStyle(FFTheme.danger)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Validate button
                        FFButton(
                            title: validating ? lang.t("validating") : lang.t("validate"),
                            icon: validating ? nil : "checkmark.shield.fill",
                            action: validate,
                            isLoading: validating,
                            isDisabled: keyInput.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                    }
                    .padding(20)
                    .background(FFTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: FFTheme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FFTheme.cornerRadius, style: .continuous)
                            .strokeBorder(FFTheme.glassBorder, lineWidth: 0.8)
                    )
                    .padding(.horizontal, 24)

                    // ── Device info pills ──
                    VStack(spacing: 8) {
                        // iPhone chip
                        HStack(spacing: 10) {
                            Image(systemName: "iphone")
                                .font(.system(size: 13))
                                .foregroundStyle(FFTheme.textSecondary)
                            Text(DeviceID.iPhoneModel)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(FFTheme.text)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(FFTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: FFTheme.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FFTheme.cornerRadius, style: .continuous)
                                .strokeBorder(FFTheme.glassBorder, lineWidth: 0.8)
                        )

                        // iOS + supported chip
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 13))
                                .foregroundStyle(FFTheme.textSecondary)
                            Text("iOS \(supportStatus.version)")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(FFTheme.text)
                            Spacer()

                            // Verified pill — green rosette style
                            HStack(spacing: 5) {
                                Image(systemName: supportStatus.isSupported
                                      ? "checkmark.seal.fill"
                                      : "xmark.seal.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(supportStatus.isSupported
                                                     ? FFTheme.success : FFTheme.danger)
                                Text(supportStatus.isSupported ? "SUPPORTED" : "NO SUPPORT")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(supportStatus.isSupported
                                                     ? FFTheme.success : FFTheme.danger)
                                    .tracking(0.6)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background((supportStatus.isSupported
                                         ? FFTheme.success : FFTheme.danger).opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().strokeBorder(
                                    (supportStatus.isSupported
                                     ? FFTheme.success : FFTheme.danger).opacity(0.30),
                                    lineWidth: 0.8
                                )
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(FFTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: FFTheme.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FFTheme.cornerRadius, style: .continuous)
                                .strokeBorder(FFTheme.glassBorder, lineWidth: 0.8)
                        )
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 48)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: error)
        .onAppear {
            if let stored = LicenseService.storedKey() { keyInput = stored }
        }
    }

    private func validate() {
        let key = keyInput.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        error = nil
        validating = true
        Task {
            do {
                let info = try await LicenseService.validate(key: key)
                await MainActor.run {
                    validating = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        onSuccess(info)
                    }
                }
            } catch {
                await MainActor.run {
                    validating = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Placeholder helper

extension View {
    @ViewBuilder
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder() }
            self
        }
    }
}

// MARK: - Support model

struct IOSSupportStatus {
    let version: String
    let isSupported: Bool
}
