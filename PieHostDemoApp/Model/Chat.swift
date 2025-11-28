//
//  Chat.swift
//  RealTimeChat
//
//   Created by Priyanka Ghosh on 28/11/25.
//

import Foundation

struct Chat: Identifiable {
    let id = UUID()
    let participant: User
    var messages: [Message] = []
    var lastReadMessageId: UUID? = nil
    var cachedUnreadCount: Int = 0

    var unreadCount: Int {
        cachedUnreadCount
    }

    var lastMessagePreview: String {
        messages.last?.text ?? "No messages yet"
    }

    var name: String {
        participant.name
    }
    
    mutating func updateMessageCounts() {
        if let lastReadId = lastReadMessageId,
           let index = messages.firstIndex(where: { $0.id == lastReadId }) {
            cachedUnreadCount = messages[(index + 1)...].filter { !$0.isSentByUser }.count
        } else {
            cachedUnreadCount = messages.filter { !$0.isSentByUser }.count
        }
    }

}
