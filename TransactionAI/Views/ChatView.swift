import SwiftUI
import GenerativeUIDSL

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
                PromptInputView(isLoading: isLoading) { prompt in
                    Task { await sendMessage(prompt) }
                }
            }
            .navigationTitle("TransactionAI")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Ask about your transactions")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                suggestionButton("Show me all expenses at McDonald's")
                suggestionButton("How much did I spend on groceries?")
                suggestionButton("Compare my spending by category")
            }
            Spacer()
        }
        .padding()
    }

    private func suggestionButton(_ text: String) -> some View {
        Button {
            Task { await sendMessage(text) }
        } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        ChatMessageView(message: message)
                            .id(message.id)
                    }
                    if isLoading {
                        LoadingView()
                            .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) {
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: isLoading) {
                if isLoading {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(role: .user, text: text)
        messages.append(userMessage)
        isLoading = true

        do {
            let response = try await ClaudeService.shared.sendQuery(
                prompt: text,
                csvContent: CSVParser.rawCSVContent()
            )
            let aiMessage = ChatMessage(role: .assistant, text: response.spokenSummary, uiResponse: response)
            messages.append(aiMessage)
        } catch {
            let errorMessage = ChatMessage(role: .assistant, text: "Sorry, something went wrong: \(error.localizedDescription)")
            messages.append(errorMessage)
        }

        isLoading = false
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    var uiResponse: UIResponse?

    enum Role {
        case user, assistant
    }
}

// MARK: - Chat Message View

struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            if message.role == .user {
                HStack {
                    Spacer()
                    Text(message.text)
                        .padding(12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else if let uiResponse = message.uiResponse {
                // Render generative UI from DSL
                VStack(alignment: .leading, spacing: 12) {
                    Text(uiResponse.title)
                        .font(.headline)
                    NodeRenderer(node: uiResponse.layout)
                    Text(uiResponse.spokenSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Plain text fallback
                Text(message.text)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .opacity(dotCount % 3 == index ? 1.0 : 0.3)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timer) { _ in dotCount += 1 }
    }
}

#Preview {
    ChatView()
}
