//
//  SettingsView.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 11/12/2023.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var ollamaUri: String
    @Binding var systemPrompt: String
    @Binding var vibrations: Bool
    @Binding var colorScheme: AppColorScheme
    @Binding var defaultOllamModel: String
    @Binding var ollamaBearerToken: String
    @Binding var appUserInitials: String
    @Binding var pingInterval: String
    @Binding var voiceIdentifier: String
    @State var ollamaStatus: Bool?
    var save: () -> ()
    var checkServer: () -> ()
    var deleteAll: () -> ()
    var ollamaLangugeModels: [LanguageModelSD]
    var voices: [AVSpeechSynthesisVoice]

    @State private var deleteConversationsDialog = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Ollama server URI", text: $ollamaUri, onCommit: checkServer)
                        .textContentType(.URL)
                        .disableAutocorrection(true)
#if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
#endif

                    TextField("Bearer Token", text: $ollamaBearerToken)
                        .disableAutocorrection(true)
#if os(iOS)
                        .autocapitalization(.none)
#endif

                    TextField("Ping Interval (seconds)", text: $pingInterval)
                        .disableAutocorrection(true)
                } header: {
                    Text("Ollama")
                }

                Section {
                    Picker(selection: $defaultOllamModel) {
                        ForEach(ollamaLangugeModels, id: \.self) { model in
                            Text(model.name).tag(model.name)
                        }
                    } label: {
                        Label("Default Model", systemImage: "cpu")
                    }
                }

                Section {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 100)
                } header: {
                    Text("System Prompt")
                }

#if os(iOS)
                Section {
                    Toggle(isOn: $vibrations) {
                        Label("Vibrations", systemImage: "water.waves")
                    }
                }
#endif

                Section {
                    Picker(selection: $colorScheme) {
                        ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                            Text(scheme.toString).tag(scheme.id)
                        }
                    } label: {
                        Label("Appearance", systemImage: "sun.max")
                    }

                    Picker(selection: $voiceIdentifier) {
                        ForEach(voices, id: \.self.identifier) { voice in
                            Text(voice.prettyName).tag(voice.identifier)
                        }
                    } label: {
                        Label("Voice", systemImage: "waveform")
                    }

                    TextField("Initials", text: $appUserInitials)
                        .disableAutocorrection(true)
#if os(iOS)
                        .autocapitalization(.none)
#endif
                } header: {
                    Text("App")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
#if os(macOS)
                        Text("Download voices: Settings > Accessibility > Spoken Content > System Voice > Manage Voices.")
#else
                        Text("Download voices: Settings > Accessibility > Spoken Content > Voices.")
#endif
                        Button {
#if os(macOS)
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?SpeakableItems") {
                                NSWorkspace.shared.open(url)
                            }
#else
                            if let url = URL(string: "App-Prefs:root=General&path=ACCESSIBILITY") {
                                UIApplication.shared.open(url)
                            }
#endif
                        } label: {
                            Text("Open System Settings")
                        }
                    }
                }

                Section {
                    Button("Clear All Data", role: .destructive) {
                        deleteConversationsDialog.toggle()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                }
            }
            .confirmationDialog("Delete All Conversations?", isPresented: $deleteConversationsDialog) {
                Button("Delete", role: .destructive) { deleteAll() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Delete All Conversations?")
            }
        }
        .preferredColorScheme(colorScheme.toiOSFormat)
    }
}

#Preview {
    SettingsView(
        ollamaUri: .constant(""),
        systemPrompt: .constant("You are an intelligent assistant solving complex problems."),
        vibrations: .constant(true),
        colorScheme: .constant(.light),
        defaultOllamModel: .constant("llama2"),
        ollamaBearerToken: .constant("x"),
        appUserInitials: .constant("AM"),
        pingInterval: .constant("5"),
        voiceIdentifier: .constant("sample"),
        save: {},
        checkServer: {},
        deleteAll: {},
        ollamaLangugeModels: LanguageModelSD.sample,
        voices: []
    )
}