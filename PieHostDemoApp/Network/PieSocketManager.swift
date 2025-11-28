//
//  PieSocketManager.swift
//  RealTimeChat
//
//   Created by Priyanka Ghosh on 28/11/25.
//

import Foundation
import Channels

// MARK: - PieSocket Delegate Protocols
protocol PieSocketMessageDelegate: AnyObject {
    func didReceiveMessage(payload: PublicMessagePayload)
}

protocol PieSocketStatusDelegate: AnyObject {
    func socketStatusDidChange(isConnected: Bool)
}

class PieSocketManager {
    static let shared = PieSocketManager()

    private var piesocket: PieSocket?
    private var channel: Channel?  // Single channel for single bot chat
    private var listeners: [String] = [] // List of listener IDs

    // Delegate pattern instead of Combine
    weak var messageDelegate: PieSocketMessageDelegate?
    weak var statusDelegate: PieSocketStatusDelegate?

    private init() {

    }
    
    func connect(roomId: String, userId: String) {
        // Initialize PieSocket if not already done
        if piesocket == nil {
            let options = PieSocketOptions()
            options.setClusterId(clusterId: "s15487.blr1")
            options.setApiKey(apiKey: "gULiXeKRMsCUmv1Sy0uGdrmRTn7J8KCPevg7Iejr")
            options.setUserId(userId: userId)

            piesocket = PieSocket(pieSocketOptions: options)
        }

        // Join the single chat room
        let joinedChannel = piesocket!.join(roomId: roomId)
        channel = joinedChannel

        // Connected event listener
        let connectedListener = joinedChannel.listen(eventName: "system:connected") { [weak self] _ in
            DispatchQueue.main.async {
                self?.statusDelegate?.socketStatusDidChange(isConnected: true)
            }
        }
        listeners.append(connectedListener)

        // Closed event listener
        let closedListener = joinedChannel.listen(eventName: "system:closed") { [weak self] _ in
            DispatchQueue.main.async {
                self?.statusDelegate?.socketStatusDidChange(isConnected: false)
            }
        }
        listeners.append(closedListener)

        // Message event listener
        let messageListener = joinedChannel.listen(eventName: "system:message") { [weak self] event in
            guard let self = self else { return }
            let raw = event.getData()

            if let json = self.extractUnescapedDataPayload(from: raw),
               let jsonData = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let text = dict["text"] as? String,
               let senderId = dict["senderId"] as? String,
               let receiverId = dict["receiverId"] as? String {
                let payload = PublicMessagePayload(text: text, senderId: senderId, receiverId: receiverId)
                DispatchQueue.main.async {
                    self.messageDelegate?.didReceiveMessage(payload: payload)
                }
            }
        }
        listeners.append(messageListener)
    }
    
    func publish(to roomId: String, payload: PublicMessagePayload) {
        guard let channel = channel else { return }
        guard let encoded = try? JSONEncoder().encode(payload),
              let jsonString = String(data: encoded, encoding: .utf8) else {
            return
        }

        let event = PieSocketEvent(event: "new-message")
        event.setData(data: jsonString)
        channel.publish(event: event)
    }
    
    func reconnect(roomId: String) {
        guard let channel = channel else { return }
        channel.reconnect()
    }

    func disconnect(roomId: String) {
        guard let channel = channel else { return }

        // Remove all listeners
        listeners.forEach { listenerId in
            channel.removeListener(eventName: "system:connected", callbackId: listenerId)
            channel.removeListener(eventName: "system:closed", callbackId: listenerId)
            channel.removeListener(eventName: "system:message", callbackId: listenerId)
        }

        channel.disconnect()
        self.channel = nil
        listeners.removeAll()
    }

    func disconnectAll() {
        disconnect(roomId: "") // Room ID doesn't matter for single channel
        piesocket = nil
        DispatchQueue.main.async { [weak self] in
            self?.statusDelegate?.socketStatusDidChange(isConnected: false)
        }
    }
    
    private func extractUnescapedDataPayload(from raw: String) -> String? {
        guard let dataKeyRange = raw.range(of: "\"data\"") else { return nil }
        guard let startBrace = raw[dataKeyRange.upperBound...].firstIndex(of: "{") else { return nil }
        
        var braceCount = 0
        var endIndex: String.Index? = nil
        for index in raw[startBrace...].indices {
            let char = raw[index]
            if char == "{" { braceCount += 1 }
            if char == "}" { braceCount -= 1 }
            if braceCount == 0 {
                endIndex = index
                break
            }
        }
        guard let end = endIndex else { return nil }
        let innerJSON = raw[startBrace...end]
        return String(innerJSON)
    }
}
