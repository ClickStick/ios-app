//  ClickStick Companion app
//  Copyright © 2026 KeePassium Labs <info@keepassium.com>

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsStorage.autoSelectLastDevice) private var autoSelectLastDevice = true
    @AppStorage(SettingsStorage.keepScreenOn) private var keepScreenOn = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    SettingsSection(title: "General") {
                        SettingsToggleRow(
                            title: "Auto-select last device",
                            subtitle: "Connect automatically on launch",
                            isOn: $autoSelectLastDevice
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            title: "Keep screen on",
                            subtitle: "Prevent sleep while connected",
                            isOn: $keepScreenOn
                        )
                    }

                    SettingsSection(title: "Help") {
                        SettingsNavigationRow(
                            icon: "info.circle",
                            title: "How it works"
                        )

                        SettingsDivider()

                        SettingsActionRow(
                            icon: "cart",
                            title: "Get your ClickStick at clickstick.io",
                            titleColor: .accentBlue
                        ) {
                            URLOpener().openGettingStartedPage()
                        }
                    }

                    SettingsSection(title: "Legal") {
                        SettingsActionRow(
                            icon: "doc.text",
                            title: "Privacy Policy"
                        ) {}

                        SettingsDivider()

                        SettingsActionRow(
                            icon: "doc.plaintext",
                            title: "Terms of Use"
                        ) {}
                    }

                    Text("Version \(appVersion)")
                        .font(.footnote)
                        .foregroundStyle(.secondary.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(Color.groupedBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.primary)
                    }
                    .accessibilityLabel("Close settings")
                }
            }
        }
        .tint(.accentBlue)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.groupedBackground)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}

private struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.cardBackground)
            )
        }
    }
}

private struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(Color(uiColor: .systemGreen))
        }
        .frame(minHeight: 60)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsNavigationRow: View {
    let icon: String
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.65))
        }
        .frame(minHeight: 56)
        .padding(.horizontal, 16)
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let title: LocalizedStringKey
    var titleColor: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(titleColor)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.body)
                    .foregroundStyle(titleColor)

                Spacer(minLength: 12)
            }
            .frame(minHeight: 56)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 0.5)
            .padding(.leading, 16)
            .padding(.trailing, 20)
    }
}

#Preview {
    SettingsView()
}
