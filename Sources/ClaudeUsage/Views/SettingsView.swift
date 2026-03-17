import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var isTestingConnection: Bool {
        appState.connectionState == .testing
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Text(L10n.tr("settings.tab.general")) }
            notificationsTab
                .tabItem { Text(L10n.tr("settings.tab.notifications")) }
            connectionTab
                .tabItem { Text(L10n.tr("settings.tab.connection")) }
            advancedTab
                .tabItem { Text(L10n.tr("settings.tab.advanced")) }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [claudeBackground, claudeSecondaryBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .preferredColorScheme(.dark)
    }

    private var generalTab: some View {
        settingsScroll {
            formSection(title: L10n.tr("settings.section.display")) {
                labeledRow(L10n.tr("settings.display.menu_bar")) {
                    Picker(L10n.tr("settings.display.menu_bar_picker"), selection: Binding(
                        get: { appState.preferences.menuBarDisplayMode },
                        set: { newValue in appState.updatePreferences { $0.menuBarDisplayMode = newValue } }
                    )) {
                        ForEach(AppPreferences.MenuBarDisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }

                labeledRow(L10n.tr("settings.display.refresh")) {
                    Picker(L10n.tr("settings.display.refresh_interval"), selection: Binding(
                        get: { appState.preferences.refreshIntervalMinutes },
                        set: { newValue in appState.updatePreferences { $0.refreshIntervalMinutes = newValue } }
                    )) {
                        ForEach([2, 5, 10, 15], id: \.self) { minutes in
                            Text(L10n.tr("common.minutes_short", minutes)).tag(minutes)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 120)
                }
            }

            formSection(title: L10n.tr("settings.section.session")) {
                Toggle(L10n.tr("settings.session.launch_at_login"), isOn: Binding(
                    get: { appState.preferences.launchAtLogin },
                    set: { newValue in appState.updatePreferences { $0.launchAtLogin = newValue } }
                ))
                .toggleStyle(.switch)
                .foregroundStyle(claudeTextPrimary)
            }
        }
    }

    private var notificationsTab: some View {
        settingsScroll {
            formSection(title: L10n.tr("settings.section.thresholds")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("settings.threshold.warning", Int(appState.preferences.warningThreshold * 100)))
                        .foregroundStyle(claudeTextPrimary)
                    Slider(value: Binding(
                        get: { appState.preferences.warningThreshold },
                        set: { newValue in appState.updatePreferences { $0.warningThreshold = newValue } }
                    ), in: 0.6...0.9)
                    .tint(claudeAmber)
                }
            }

            formSection(title: L10n.tr("settings.section.notifications")) {
                Toggle(L10n.tr("settings.notifications.reset"), isOn: Binding(
                    get: { appState.preferences.resetNotificationsEnabled },
                    set: { newValue in appState.updatePreferences { $0.resetNotificationsEnabled = newValue } }
                ))

                Toggle(L10n.tr("settings.notifications.sync_error"), isOn: Binding(
                    get: { appState.preferences.syncErrorNotificationsEnabled },
                    set: { newValue in appState.updatePreferences { $0.syncErrorNotificationsEnabled = newValue } }
                ))

                Toggle(L10n.tr("settings.notifications.usage"), isOn: Binding(
                    get: { appState.preferences.usageNotificationsEnabled },
                    set: { newValue in appState.updatePreferences { $0.usageNotificationsEnabled = newValue } }
                ))
            }
        }
    }

    private var connectionTab: some View {
        settingsScroll {
            formSection(title: L10n.tr("settings.section.claude_connection")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("settings.connection.session_key"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(claudeTextPrimary)
                    SecureField(L10n.tr("settings.connection.session_key_placeholder"), text: $appState.sessionKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isTestingConnection)

                    if !appState.storedSessionKeyMask.isEmpty {
                        Text(L10n.tr("settings.connection.saved_session", appState.storedSessionKeyMask))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(claudeAmber)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("settings.connection.organization_id"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(claudeTextPrimary)
                    TextField(
                        L10n.tr("settings.connection.organization_id_placeholder"),
                        text: Binding(
                            get: { appState.organizationID },
                            set: { appState.updateOrganizationID($0) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .disabled(isTestingConnection)
                }

                HStack(spacing: 12) {
                    Button(isTestingConnection ? L10n.tr("settings.connection.testing") : L10n.tr("settings.connection.test")) {
                        Task { await appState.saveSessionKey() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTestingConnection)

                    Button(L10n.tr("settings.connection.clear")) {
                        Task { await appState.clearSessionKey() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingConnection)
                }

                if isTestingConnection {
                    HStack(alignment: .center, spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.tr("settings.connection.testing_detail"))
                            .foregroundStyle(claudeTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(L10n.tr("settings.connection.status", appState.connectionState.label))
                        .foregroundStyle(claudeTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            formSection(title: L10n.tr("settings.section.help")) {
                Text(L10n.tr("settings.help.step_1"))
                Text(L10n.tr("settings.help.step_2"))
                Text(L10n.tr("settings.help.step_3"))
                Text(L10n.tr("settings.help.step_4"))
                Text(L10n.tr("settings.help.organization_id_hint"))
                    .foregroundStyle(claudeAmber)
                Text(L10n.tr("settings.help.organization_id_fallback"))
                    .foregroundStyle(claudeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var advancedTab: some View {
        settingsScroll {
            formSection(title: L10n.tr("settings.section.workspace")) {
                Button(L10n.tr("settings.workspace.open_insights")) {
                    appState.openInsights()
                }
                .buttonStyle(.borderedProminent)

                Button(L10n.tr("settings.workspace.open_diagnostics")) {
                    appState.openDiagnostics()
                }
                .buttonStyle(.bordered)
            }

            formSection(title: L10n.tr("settings.section.data")) {
                Button(L10n.tr("settings.data.export_history")) {
                    appState.exportHistory()
                }
                .buttonStyle(.bordered)
            }

            formSection(title: L10n.tr("settings.section.about")) {
                labeledRow(L10n.tr("settings.about.version")) {
                    Text(AppMetadata.displayVersion)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(claudeAmber)
                }
            }
        }
    }

    private func settingsScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16, content: content)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, 8)
        }
    }

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(claudeSecondaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(claudeBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topLeading) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(claudeTextSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(claudeBackground)
                    .offset(x: 12, y: -14)
            }
            .padding(.top, 8)
    }

    private func labeledRow<Content: View>(_ title: String, @ViewBuilder control: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .foregroundStyle(claudeTextPrimary)
            Spacer()
            control()
        }
    }
}
