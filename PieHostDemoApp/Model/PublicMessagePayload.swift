//
//  PublicMessagePayload.swift
//  RealTimeChat
//
//   Created by Priyanka Ghosh on 28/11/25.
//

import Foundation

struct PublicMessagePayload: Codable {
    let text: String
    let senderId: String
    let receiverId: String
}
