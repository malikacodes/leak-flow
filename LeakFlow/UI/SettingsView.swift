import SwiftUI

/// Main settings window for Leak Flow
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var permissionManager = PermissionManager.shared
    @ObservedObject var modelDownloader: ModelDownloader

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ModelSettingsTab(settings: settings, modelDownloader: modelDownloader)
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }

            StatusSettingsTab(permissionManager: permissionManager, modelDownloader: modelDownloader, settings: settings)
                .tabItem {
                    Label("Status", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 320)
        .padding()
    }
}

/// General settings: hotkey, behavior toggles
struct GeneralSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @State private var isRecordingHotkey = false

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Push-to-talk key:")
                    Spacer()

                    if isRecordingHotkey {
                        Text("Press a key...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.accentColor, lineWidth: 2)
                            )
                    } else {
                        Button(settings.hotkeyBinding.displayString) {
                            isRecordingHotkey = true
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                }

                if isRecordingHotkey {
                    HotkeyRecorderView(isRecording: $isRecordingHotkey) { binding in
                        settings.hotkeyBinding = binding
                    }
                    .frame(height: 0)
                }
            }

            Section("Behavior") {
                Toggle("Auto-paste into active field", isOn: $settings.autoPasteEnabled)

                Toggle("Copy to clipboard", isOn: $settings.copyToClipboardEnabled)
                    .disabled(!settings.autoPasteEnabled)

                Toggle("Play sounds on record start/stop", isOn: $settings.playSoundsEnabled)

                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }
}

/// Model selection and download management
struct ModelSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelDownloader: ModelDownloader

    var body: some View {
        Form {
            Section("Whisper Model") {
                ForEach(ModelDownloader.WhisperModel.allCases) { model in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                                .font(.body)

                            if modelDownloader.isModelDownloaded(model) {
                                Text("Downloaded")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if modelDownloader.isDownloading[model.rawValue] == true {
                                let progress = modelDownloader.downloadProgress[model.rawValue] ?? 0
                                ProgressView(value: progress) {
                                    Text("Downloading \(Int(progress * 100))%")
                                        .font(.caption)
                                }
                            } else {
                                Text("Not downloaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if modelDownloader.isModelDownloaded(model) {
                            if settings.selectedModel == model.rawValue {
                                Text("Active")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(4)
                            } else {
                                Button("Select") {
                                    settings.selectedModel = model.rawValue
                                }
                            }
                        } else if modelDownloader.isDownloading[model.rawValue] == true {
                            Button("Cancel") {
                                modelDownloader.cancelDownload(model)
                            }
                        } else {
                            Button("Download") {
                                modelDownloader.downloadModel(model) { _ in }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Permission and system status
struct StatusSettingsTab: View {
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var modelDownloader: ModelDownloader
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Permissions") {
                HStack {
                    Text("Microphone Access")
                    Spacer()
                    if permissionManager.microphoneGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        HStack {
                            Label("Denied", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Button("Open Settings") {
                                permissionManager.openMicrophoneSettings()
                            }
                            .buttonStyle(.link)
                        }
                    }
                }

                HStack {
                    Text("Accessibility Access")
                    Spacer()
                    if permissionManager.accessibilityGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        HStack {
                            Label("Not Granted", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Button("Open Settings") {
                                permissionManager.openAccessibilitySettings()
                            }
                            .buttonStyle(.link)
                        }
                    }
                }
            }

            Section("Model Status") {
                HStack {
                    Text("Active Model")
                    Spacer()
                    if let model = ModelDownloader.WhisperModel(rawValue: settings.selectedModel),
                       modelDownloader.isModelDownloaded(model) {
                        Text(model.displayName)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No model loaded")
                            .foregroundColor(.red)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    // Reads the version number from the app itself (set as MARKETING_VERSION
                    // in the Xcode project), so it's always right after a version bump
                    Text("Leak Flow v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }
}
