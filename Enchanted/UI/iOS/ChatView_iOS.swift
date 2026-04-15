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
    @State private var searchQuery = ""

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


    private var filteredConversationGroups: [ConversationGroup] {
        let groups = conversationGroups
        if searchQuery.isEmpty { return groups }
        return groups.compactMap { group in
            let filtered = group.conversations.filter { conversation in
                conversation.name.localizedCaseInsensitiveContains(searchQuery)
            }
            return filtered.isEmpty ? nil : ConversationGroup(date: group.date, conversations: filtered)
        }
    }

    var inputFields: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PhotosPicker(selection: $pickerSelectorActive) {
                Image(systemName: "photo")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .onChange(of: pickerSelectorActive) {
                Task {
                    if let loaded = try? await pickerSelectorActive?.loadTransferable(type: Image.self) {
                        selectedImage = loaded
                    }
                }
            }
            .showIf(selectedModel?.supportsImages ?? false)

            CapsuleInputField()
        }
        .onTapGesture {
            isFocusedInput = true
        }
    }

    @ViewBuilder
    private func CapsuleInputField() -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            if selectedImage != nil {
                SelectedImageView(image: $selectedImage)
            }

            TextField("Message", text: $message, axis: .vertical)
                .focused($isFocusedInput)
                .font(.body)
                .lineLimit(1...5)

            RecordingView(speechRecognizer: speechRecognizer, isRecording: $isRecording.animation()) { transcription in
                self.message = transcription
            }

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
                    Button(action: onMessageSubmit) {
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
        .glassEffect(in: .capsule)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                inputFields
                    .padding(.horizontal)
                    .padding(.vertical, 5)
            }
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
                        ForEach(filteredConversationGroups, id: \.self) { group in
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
                    .searchable(text: $searchQuery, prompt: "Search conversations")
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