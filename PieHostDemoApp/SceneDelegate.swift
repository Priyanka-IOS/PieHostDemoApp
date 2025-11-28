//
//  SceneDelegate.swift
//  PieHostDemoApp
//
//   Created by Priyanka Ghosh on 28/11/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Create window
        window = UIWindow(windowScene: windowScene)

        // Set root view controller - directly show chat (single bot conversation)
        let messageManager = MessageManager.shared

        // Initialize with default user and bot
        let defaultUser = User(id: "user-1", name: "User")
        messageManager.login(as: defaultUser)

        // Show chat detail directly (single bot chat)
        if let botChat = messageManager.chats.first {
            messageManager.selectChat(botChat)
            let chatDetailVC = ChatDetailViewController(chat: botChat)
            let navigationController = UINavigationController(rootViewController: chatDetailVC)
            window?.rootViewController = navigationController
        }

        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Reconnect socket if needed when app becomes active
        MessageManager.shared.reconnectSocketIfNeeded()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Clear all chats when app goes to background (simulates app close)
        MessageManager.shared.clearAllChats()
    }


}

