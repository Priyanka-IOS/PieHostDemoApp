//
//  Message.swift .swift
//  RealTimeChat
//
//   Created by Priyanka Ghosh on 28/11/25.
//

import Foundation

struct Message: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let isSentByUser: Bool
    let sender: User
    let receiver: User
    var isQueued: Bool = false
    var isRead: Bool = false
}
