//
//  InputFields_macOS.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 10/02/2024.
//

#if os(macOS) || os(visionOS)
import SwiftUI

struct InputFieldsView: View {
    @Binding var message: String
    var conversationState: ConversationState
    var onStopGenerateTap: @MainActor () -> Void
    var selectedModel: LanguageModelSD?
    var onSendMessageTap: @MainActor (_ prompt: String, _ model: LanguageModelSD, _ image: Image?, _ trimmingMessageId: String?) -> ()
    @Binding var editMessage: MessageSD?
    @State var isRecording = false
    
    @State private var selectedImage: Image?
    @State private var fileDropActive: Bool = false
    @State private var fileSelectingActive: Bool = false
    @FocusState private var isFocusedInput: Bool
    
    @MainActor private func sendMessage() {
        guard let selectedModel = selectedModel else { return }
        
        onSendMessageTap(
            message,
            selectedModel,
            selectedImage,
            editMessage?.id.uuidString
        )
        withAnimation {
            isRecording = false
            isFocusedInput = false
            editMessage = nil
            selectedImage = nil
            message = ""
        }
    }
    
    private func updateSelectedImage(_ image: Image) {
        selectedImage = image
    }
    
#if os(macOS)
    var hotkeys: [HotkeyCombination] {
        [
            HotkeyCombination(keyBase: [.command], key: .kVK_ANSI_V) {
                if let nsImage = Clipboard.shared.getImage() {
                    let image = Image(nsImage: nsImage)
                    updateSelectedImage(image)
                }
            }
        ]
    }
#endif
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let image = selectedImage {
                RemovableImage(
                    image: image,
                    onClick: { selectedImage = nil },
                    height: 50
                )
            }

            HStack(alignment: .bottom, spacing: 6) {
                TextField("Message", text: $message.animation(.easeOut(duration: 0.3)), axis: .vertical)
                    .focused($isFocusedInput)
                    .font(.body)
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
#if os(macOS)
                    .onSubmit {
                        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                            message += "\n"
                        } else {
                            sendMessage()
                        }
                    }
#endif
                    .allowsHitTesting(!fileDropActive)
#if os(macOS)
                    .addCustomHotkeys(hotkeys)
#endif

                RecordingView(isRecording: $isRecording.animation()) { transcription in
                    withAnimation(.easeIn(duration: 0.3)) {
                        self.message = transcription
                    }
                }

                SimpleFloatingButton(systemImage: "photo.fill", onClick: { fileSelectingActive.toggle() })
                    .showIf(selectedModel?.supportsImages ?? false)
                    .fileImporter(isPresented: $fileSelectingActive,
                                  allowedContentTypes: [.png, .jpeg, .tiff],
                                  onCompletion: { result in
                        switch result {
                        case .success(let url):
                            guard url.startAccessingSecurityScopedResource() else { return }
                            if let imageData = try? Data(contentsOf: url) {
                                selectedImage = Image(data: imageData)
                            }
                            url.stopAccessingSecurityScopedResource()
                        case .failure(let error):
                            print(error)
                        }
                    })

                switch conversationState {
                case .loading:
                    Button(action: onStopGenerateTap) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                default:
                    if !message.isEmpty || selectedImage != nil {
                        Button(action: { Task { sendMessage() } }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(in: .rect(cornerRadius: 20))
        }
        .animation(.default, value: fileDropActive)
        .overlay {
            if fileDropActive {
                DragAndDrop(cornerRadius: 20)
            }
        }
        .onDrop(of: [.image], isTargeted: $fileDropActive.animation(), perform: { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadDataRepresentation(for: .image) { data, error in
                if error == nil, let data {
                    selectedImage = Image(data: data)
                }
            }
            
            return true
        })
        .onTapGesture {
            isFocusedInput = true
        }
    }
}

#Preview {
    @State var message = ""
    return InputFieldsView(
        message: $message,
        conversationState: .completed,
        onStopGenerateTap: {},
        onSendMessageTap: {_, _, _, _  in},
        editMessage: .constant(nil)
    )
}
#endif
