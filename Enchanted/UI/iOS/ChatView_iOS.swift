//
//  ChatView.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 09/12/2023.
//

#if os(iOS)
import SwiftUI
import PhotosUI

struct ChatView: View {
    var conversation: ConversationSD?
    var conversations: [ConversationSD]
    var messages: [MessageSD]
    var modelsList: [LanguageModelSD]
    var onNewConversationTap: () -> ()
    var onSendMessageTap: @MainActor (_ prompt: String, _ model: LanguageModelSD, _ image: Image?, _ trimmingMessageId: String?) -> ()
    var conversationState: ConversationState
    var onStopGenerateTap: @MainActor () -> ()
    var reachable: Bool
    var onSelectModel: @MainActor (_ model: LanguageModelSD?) -> ()
    var onConversationTap: (_ conversation: ConversationSD) -> ()
    var onConversationDelete: (_ conversation: ConversationSD) -> ()
    var onDeleteDailyConversations: (_ date: Date) -> ()
    var userInitials: String

    private var selectedModel: LanguageModelSD?
    @State private var message = ""
    @State private var isRecording = false
    @State private var editMessage: MessageSD?
    @FocusState private var isFocusedInput: Bool
    @StateObject var speechRecognizer = SpeechRecognizer()

    /// Image selection
    @State private var pickerSelectorActive: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var showSettings = false
    @State private var showConversations = false

    init(
        conversation: ConversationSD? = nil,
        conversations: [ConversationSD],
        messages: [MessageSD],
        modelsList: [LanguageModelSD],
        selectedModel: LanguageModelSD?,
        onSelectModel: @MainActor @escaping (_ model: LanguageModelSD?) -> (),
        onNewConversationTap: @escaping () -> Void,
        onSendMessageTap: @MainActor @escaping (_ prompt: String, _ model: LanguageModelSD, _ image: Image?, _ trimmingMessageId: String?) -> Void,
        conversationState: ConversationState,
        onStopGenerateTap: @MainActor @escaping () -> Void,
        reachable: Bool,
        modelSupportsImages: Bool = false,
        userInitials: String,
        onConversationTap: @escaping (_ conversation: ConversationSD) -> Void,
        onConversationDelete: @escaping (_ conversation: ConversationSD) -> Void,
        onDeleteDailyConversations: @escaping (_ date: Date) -> Void
    ) {
        self.conversation = conversation
        self.conversations = conversations
        self.messages = messages
        self.modelsList = modelsList
        self.onNewConversationTap = onNewConversationTap
        self.onSendMessageTap = onSendMessageTap
        self.conversationState = conversationState
        self.onStopGenerateTap = onStopGenerateTap
        self.reachable = reachable
        self.onSelectModel = onSelectModel
        self.selectedModel = selectedModel
        self.userInitials = userInitials
        self.onConversationTap = onConversationTap
        self.onConversationDelete = onConversationDelete
        self.onDeleteDailyConversations = onDeleteDailyConversations
    }

    private func onMessageSubmit() {
        Task {
            await Haptics.shared.mediumTap()

            guard let selectedModel = selectedModel else { return }

            await onSendMessageTap(
                message,
                selectedModel,
                selectedImage,
                editMessage?.id.uuidString
            )

            withAnimation {
                isFocusedInput = false
                editMessage = nil
                selectedImage = nil
                message = ""
            }
        }
    }

    private var conversationGroups: [ConversationGroup] {
        let grouped = Dictionary(grouping: conversations) { conversation in
            Calendar.current.startOfDay(for: conversation.updatedAt)
        }
        return grouped.map { date, convs in
            ConversationGroup(date: date, conversations: convs)
        }.sorted { $0.date > $1.date }
    }


    var inputFields: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $pickerSelectorActive) {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.foreground)
                    .frame(height: 19)
            }
            .onChange(of: pickerSelectorActive) {
                Task {
                    if let loaded = try? await pickerSelectorActive?.loadTransferable(type: Image.self) {
                        selectedImage = loaded
                    } else {
                        print("Failed")
                    }
                }
            }
            .showIf(selectedModel?.supportsImages ?? false)


            HStack {
                SelectedImageView(image: $selectedImage)

                TextField("Message", text: $message, axis: .vertical)
                    .focused($isFocusedInput)
                    .frame(minHeight: 40)
                    .font(.system(size: 14))

                RecordingView(speechRecognizer: speechRecognizer, isRecording: $isRecording.animation()) { transcription in
                    self.message = transcription
                }
            }
            .onChange(of: isFocusedInput, { oldValue, newValue in
                withAnimation {
                    isFocusedInput = newValue
                }
            })
            .padding(.horizontal)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isRecording ? Color(.systemBlue) : Color(.systemGray2),
                        style: StrokeStyle(lineWidth: isRecording ? 2 : 0.5)
                    )
            )

            switch conversationState {
            case .loading:
                SimpleFloatingButton(systemImage: "square.fill", onClick: onStopGenerateTap)
                    .frame(width: 12)
            default:
                SimpleFloatingButton(systemImage: "paperplane.fill", onClick: onMessageSubmit)
                    .frame(width: 18)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // allow focusing text area on greater tap area
            isFocusedInput = true
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if conversation != nil {
                    MessageListView(
                        messages: messages,
                        conversationState: conversationState,
                        userInitials: userInitials,
                        editMessage: $editMessage
                    )
                } else {
                    EmptyConversaitonView(sendPrompt: { selectedMessage in
                        if let selectedModel = selectedModel {
                            onSendMessageTap(selectedMessage, selectedModel, nil, nil)
                        }
                    })
                }

                ConversationStatusView(state: conversationState)
                    .padding()

                if !reachable {
                    UnreachableAPIView()
                }

                inputFields
                    .padding(.horizontal)
            }
            .padding(.bottom, 5)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showConversations.toggle() }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                    }
                }

                ToolbarItem(placement: .principal) {
                    ModelSelectorView(
                        modelsList: modelsList,
                        selectedModel: selectedModel,
                        onSelectModel: onSelectModel
                    )
                    .showIf(!modelsList.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onNewConversationTap) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .onChange(of: editMessage, initial: false) { _, newMessage in
                if let newMessage = newMessage {
                    message = newMessage.content
                    isFocusedInput = true
                }
            }
            .sheet(isPresented: $showSettings) {
                Settings()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showConversations) {
                NavigationStack {
                    List {
                        ForEach(conversationGroups, id: \.self) { group in
                            Section {
                                ForEach(group.conversations, id: \.self) { dailyConversation in
                                    HStack {
                                        Text(dailyConversation.name)
                                            .lineLimit(1)
                                            .foregroundStyle(conversation == dailyConversation ? .primary : .secondary)
                                        Spacer()
                                        if conversation == dailyConversation {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        onConversationTap(dailyConversation)
                                        showConversations = false
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive, action: { onConversationDelete(dailyConversation) }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .contextMenu {
                                        Button(role: .destructive, action: { onConversationDelete(dailyConversation) }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text(group.date.daysAgoString())
                                    .contextMenu {
                                        Button(role: .destructive, action: { onDeleteDailyConversations(group.date) }) {
                                            Label("Delete all from this day", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .navigationTitle("Recent Chats")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showConversations = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    ChatView(
        conversation: ConversationSD.sample[0],
        conversations: ConversationSD.sample,
        messages: MessageSD.sample,
        modelsList: LanguageModelSD.sample,
        selectedModel: LanguageModelSD.sample[0],
        onSelectModel: {_ in },
        onNewConversationTap: { },
        onSendMessageTap: {_,_,_,_    in},
        conversationState: .loading,
        onStopGenerateTap: {},
        reachable: false,
        modelSupportsImages: true,
        userInitials: "AM",
        onConversationTap: {_ in},
        onConversationDelete: {_ in},
        onDeleteDailyConversations: {_ in}
    )
}

#Preview {
    ChatView(
        conversation: nil,
        conversations: ConversationSD.sample,
        messages: [],
        modelsList: LanguageModelSD.sample,
        selectedModel: LanguageModelSD.sample[0],
        onSelectModel: {_ in},
        onNewConversationTap: { },
        onSendMessageTap: {_,_,_,_    in},
        conversationState: .completed,
        onStopGenerateTap: {},
        reachable: true,
        modelSupportsImages: true,
        userInitials: "AM",
        onConversationTap: {_ in},
        onConversationDelete: {_ in},
        onDeleteDailyConversations: {_ in}
    )
}
#endif