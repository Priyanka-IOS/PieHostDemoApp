//
//  MessageManager.swift
//  RealTimeChat
//
//   Created by Priyanka Ghosh on 28/11/25.
//

import Foundation
import UIKit

// MARK: - MessageManager Delegate Protocol
protocol MessageManagerDelegate: AnyObject {
    func messageManager(_ manager: MessageManager, didUpdateChats chats: [Chat])
    func messageManager(_ manager: MessageManager, didUpdateSelectedChat chat: Chat?)
    func messageManager(_ manager: MessageManager, didUpdateConnectionStatus isConnected: Bool, isSocketConnected: Bool)
    func messageManager(_ manager: MessageManager, didReceiveError message: String)
}

class MessageManager: NetworkStatusDelegate, PieSocketMessageDelegate, PieSocketStatusDelegate {

    static let shared = MessageManager()

    // MARK: - Properties
    // Single bot chat - we keep it as array with one element for compatibility
    var chats: [Chat] = [] {
        didSet {
            notifyDelegateChatsUpdated()
        }
    }

    // Selected chat will always be the bot chat
    var selectedChat: Chat? {
        didSet {
            notifyDelegateSelectedChatUpdated()
        }
    }

    var isConnected: Bool = true {
        didSet {
            notifyDelegateConnectionStatusUpdated()
        }
    }

    var isSocketConnected: Bool = true {
        didSet {
            notifyDelegateConnectionStatusUpdated()
        }
    }

    var currentUser: User? {
        didSet {
            if let user = currentUser {
                UserDefaults.standard.set(user.id, forKey: "lastUserId")
            }
        }
    }

    static let chatBot = User(id: "bot-1", name: "Support Bot")

    // Delegate
    weak var delegate: MessageManagerDelegate?

    // Private properties
    private var queuedMessages: [Message] = []
    private let retryQueue = DispatchQueue(label: "RetryQueue")
    private var debounceRetryWorkItem: DispatchWorkItem?
    private let roomId = "1"

    // MARK: - Initialization
    private init() {
        setupDelegates()
        tryAutoLogin()
    }

    private func setupDelegates() {
        NetworkStatusMonitor.shared.delegate = self
        PieSocketManager.shared.messageDelegate = self
        PieSocketManager.shared.statusDelegate = self
    }

    // MARK: - Auto Login
    func tryAutoLogin() {
        // Auto-login with default user
        let defaultUser = User(id: "user-1", name: "User")
        login(as: defaultUser)
    }

    // MARK: - Authentication
    func login(as user: User) {
        self.isConnected = NetworkStatusMonitor.shared.isConnected
        currentUser = user
        setupSocket()
        initializeBotChat()
    }

    private func initializeBotChat() {
        // Create single chat with bot
        chats = [Chat(participant: MessageManager.chatBot)]
    }

    // Logout not used in single bot chat, but kept for potential future use
    func logout() {
        currentUser = nil
        chats = []
        selectedChat = nil
        queuedMessages = []
        PieSocketManager.shared.disconnectAll()
        UserDefaults.standard.removeObject(forKey: "lastUserId")
    }

    // MARK: - Chat Selection
    func selectChat(_ chat: Chat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            selectedChat = chats[index]
            markMessagesAsRead(for: chats[index])
        }
    }

    func clearSelectedChat() {
        selectedChat = nil
    }

    // MARK: - Message Handling
    func sendMessage(_ text: String) {
        guard let currentUser = currentUser, var selected = selectedChat else { return }
        let message = Message(id: UUID(), text: text, timestamp: .now, isSentByUser: true, sender: currentUser, receiver: selected.participant)

        // Check if actually offline/disconnected
        let shouldQueue = !isSocketConnected || !isConnected

        if !shouldQueue {
            let payload = PublicMessagePayload(
                text: message.text,
                senderId: message.sender.id,
                receiverId: message.receiver.id
            )
            PieSocketManager.shared.publish(to: roomId, payload: payload)
        } else {
            var queued = message
            queued.isQueued = true
            queuedMessages.append(queued)
        }

        selected.messages.append(message)
        updateChat(selected)
    }

    func receiveMessage(_ message: Message) {
        // For single bot chat, just append to the first (and only) chat
        guard !chats.isEmpty else { return }

        var chat = chats[0]
        chat.messages.append(message)

        // Mark as read if chat is active
        if selectedChat?.id == chat.id {
            chat.lastReadMessageId = message.id
        }

        chat.updateMessageCounts()
        chats[0] = chat

        // Update selected chat if it's the current one
        if selectedChat?.id == chat.id {
            selectedChat = chat
        }
    }

    func markMessagesAsRead(for chat: Chat) {
        guard let index = chats.firstIndex(where: { $0.id == chat.id }) else { return }

        let lastMessage = chats[index].messages.last(where: { !$0.isSentByUser })
        chats[index].lastReadMessageId = lastMessage?.id
        chats[index].updateMessageCounts()
        if selectedChat?.id == chat.id {
            selectedChat = chats[index]  // Update selection if needed
        }
    }

    private func updateChat(_ chat: Chat) {
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index] = chat
            selectedChat = chat
        }
    }

    // MARK: - Socket Management
    private func setupSocket() {
        guard let userId = currentUser?.id else { return }
        PieSocketManager.shared.connect(roomId: roomId, userId: userId)
    }

    func reconnectSocketIfNeeded() {
        guard currentUser != nil else { return }
        if !isSocketConnected {
            PieSocketManager.shared.reconnect(roomId: roomId)
        }
    }

    func disconnectSocketIfNeeded() {
        PieSocketManager.shared.disconnect(roomId: roomId)
    }

    // MARK: - Message Queue & Retry
    private func retryQueuedMessages() {
        retryQueue.async { [weak self] in
            guard let self = self, self.isConnected, self.isSocketConnected, !self.queuedMessages.isEmpty else { return }

            let messageCount = self.queuedMessages.count
            for message in self.queuedMessages {
                let payload = PublicMessagePayload(
                    text: message.text,
                    senderId: message.sender.id,
                    receiverId: message.receiver.id
                )
                PieSocketManager.shared.publish(to: self.roomId, payload: payload)
            }

            self.queuedMessages.removeAll()

            DispatchQueue.main.async {
                self.showError("Successfully sent \(messageCount) queued message(s).")
            }
        }
    }

    private func scheduleRetryQueuedMessages(after delay: TimeInterval = 0.3) {
        debounceRetryWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.retryQueuedMessages()
        }
        debounceRetryWorkItem = workItem
        retryQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    // MARK: - Utility Methods
    func clearAllChats() {
        chats = []
        selectedChat = nil
        queuedMessages = []
    }

    func showError(_ message: String) {
        delegate?.messageManager(self, didReceiveError: message)
    }

    // Not needed for single bot chat - removed functionality

    // MARK: - Delegate Notifications
    private func notifyDelegateChatsUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.messageManager(self, didUpdateChats: self.chats)
        }
    }

    private func notifyDelegateSelectedChatUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.messageManager(self, didUpdateSelectedChat: self.selectedChat)
        }
    }

    private func notifyDelegateConnectionStatusUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.messageManager(self, didUpdateConnectionStatus: self.isConnected, isSocketConnected: self.isSocketConnected)
        }
    }

    // MARK: - NetworkStatusDelegate
    func networkStatusDidChange(isConnected: Bool, quality: NetworkStatusMonitor.ConnectionQuality) {
        let wasConnected = self.isConnected
        self.isConnected = isConnected
        print("Network connected: \(isConnected)")

        // Show alert when network status changes
        if !wasConnected && isConnected {
            showError("Network connection restored. Retrying queued messages...")
        } else if wasConnected && !isConnected {
            showError("Network connection lost. Messages will be queued.")
        }

        if isConnected && self.isSocketConnected {
            scheduleRetryQueuedMessages()
        }

        if isConnected && !self.isSocketConnected {
            reconnectSocketIfNeeded()
        }
    }

    // MARK: - PieSocketStatusDelegate
    func socketStatusDidChange(isConnected: Bool) {
        let wasSocketConnected = self.isSocketConnected
        self.isSocketConnected = isConnected
        print("Socket connected: \(isConnected)")

        // Show alert when socket status changes
        if !wasSocketConnected && isConnected {
            showError("Socket connected successfully.")
        } else if wasSocketConnected && !isConnected {
            showError("Socket disconnected. Reconnecting...")
        }

        if self.isConnected && isConnected {
            scheduleRetryQueuedMessages()
        }
    }

    // MARK: - PieSocketMessageDelegate
    func didReceiveMessage(payload: PublicMessagePayload) {
        handleIncoming(payload)
    }

    private func handleIncoming(_ payload: PublicMessagePayload) {
        guard let currentUser = self.currentUser else { return }

        // Ignore messages not for current user
        guard payload.receiverId == currentUser.id else { return }

        // Ignore self-messages
        guard payload.senderId != currentUser.id else { return }

        // For single bot chat, sender is always the bot
        let sender = MessageManager.chatBot

        let message = Message(
            id: UUID(),
            text: payload.text,
            timestamp: Date.now,
            isSentByUser: false,
            sender: sender,
            receiver: currentUser
        )
        self.receiveMessage(message)
    }
}
