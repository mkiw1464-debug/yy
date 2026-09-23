import SwiftUI

struct LanguagePickerView: View {
    @AppStorage(FFLanguage.storageKey) private var storedLang = FFLanguage.english.rawValue
    @State private var selected: FFLanguage = .english
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            FFBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                // Logo / Title
                VStack(spacing: 12) {
                    Image(systemName: "scope")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FFTheme.accent, FFTheme.accentAlt],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.bottom, 4)

                    Text("FF External")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(FFTheme.text)

                    Text(selected.t("select_language"))
                        .font(FFTheme.subtitleFont)
                        .foregroundStyle(FFTheme.textSecondary)
                }
                .padding(.bottom, 36)

                // Language options
                VStack(spacing: 10) {
                    ForEach(FFLanguage.allCases) { lang in
                        LanguageRow(
                            lang: lang,
                            isSelected: selected == lang
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selected = lang
                            }
                        }
                    }
                }
                .glassCard()
                .padding(.horizontal, 24)

                Spacer()

                // Continue button
                FFButton(
                    title: selected.t("continue"),
                    icon: "arrow.right.circle.fill"
                ) {
                    storedLang = selected.rawValue
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        onContinue()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            if let lang = FFLanguage(rawValue: storedLang) {
                selected = lang
            }
        }
    }
}

private struct LanguageRow: View {
    let lang: FFLanguage
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(lang.flagEmoji)
                    .font(.system(size: 26))

                Text(lang.displayName)
                    .font(FFTheme.bodyFont)
                    .foregroundStyle(FFTheme.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FFTheme.accent)
                        .font(.system(size: 18, weight: .semibold))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .strokeBorder(FFTheme.glassBorder, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
