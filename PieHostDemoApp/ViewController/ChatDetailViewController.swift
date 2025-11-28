//
//  ChatDetailViewController.swift
//  RealTimeChat
//
//   Created by Priyanka Ghosh on 28/11/25.
//

import UIKit

class ChatDetailViewController: UIViewController {

    // MARK: - Properties
    private let messageManager = MessageManager.shared
    private var chat: Chat
    private var messages: [Message] = []

    // MARK: - UI Components
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.delegate = self
        table.dataSource = self
        table.register(MessageCell.self, forCellReuseIdentifier: MessageCell.identifier)
        table.separatorStyle = .none
        table.backgroundColor = .systemGroupedBackground
        table.translatesAutoresizingMaskIntoConstraints = false
        table.keyboardDismissMode = .interactive
        return table
    }()

    private let statusBanner: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let inputContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let messageTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Type a message..."
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Send", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var statusBannerHeightConstraint: NSLayoutConstraint!
    private var inputContainerBottomConstraint: NSLayoutConstraint!

    // MARK: - Initialization
    init(chat: Chat) {
        self.chat = chat
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupMessageManagerDelegate()
        loadMessages()
        setupKeyboardObservers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadMessages()
        scrollToBottom(animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        messageManager.clearSelectedChat()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = chat.name

        // Add status banner
        statusBanner.addSubview(statusLabel)
        view.addSubview(statusBanner)
        view.addSubview(tableView)

        // Add input container
        inputContainerView.addSubview(messageTextField)
        inputContainerView.addSubview(sendButton)
        view.addSubview(inputContainerView)

        statusBannerHeightConstraint = statusBanner.heightAnchor.constraint(equalToConstant: 0)
        inputContainerBottomConstraint =
            inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)

        NSLayoutConstraint.activate([
            statusBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            statusBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBannerHeightConstraint,

            statusLabel.centerYAnchor.constraint(equalTo: statusBanner.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: statusBanner.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: statusBanner.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: statusBanner.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor),

            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerBottomConstraint,
            inputContainerView.heightAnchor.constraint(equalToConstant: 60),

            messageTextField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            messageTextField.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            messageTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            messageTextField.heightAnchor.constraint(equalToConstant: 40),

            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60),
        ])

        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        updateStatusBanner()

        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - MessageManager Delegate
    private func setupMessageManagerDelegate() {
        messageManager.delegate = self
    }

    private func loadMessages() {
        if let updatedChat = messageManager.chats.first(where: { $0.id == chat.id }) {
            chat = updatedChat
            messages = chat.messages
            tableView.reloadData()
        }
    }

    private func updateStatusBanner() {
        let isConnected = messageManager.isConnected
        let isSocketConnected = messageManager.isSocketConnected

        if !isConnected {
            showStatusBanner(text: "No internet. Messages will be queued.", color: .systemRed)
        } else if !isSocketConnected {
            showStatusBanner(text: "Socket disconnected. Reconnecting...", color: .systemOrange)
        } else {
            hideStatusBanner()
        }
    }

    private func showStatusBanner(text: String, color: UIColor) {
        statusLabel.text = text
        statusBanner.backgroundColor = color
        statusBanner.isHidden = false
        statusBannerHeightConstraint.constant = 44

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    private func hideStatusBanner() {
        statusBanner.isHidden = true
        statusBannerHeightConstraint.constant = 0

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard messages.count > 0 else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }

    // MARK: - Actions
    @objc private func sendButtonTapped() {
        guard let text = messageTextField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        messageManager.sendMessage(text)
        messageTextField.text = ""
        messageTextField.resignFirstResponder()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let keyboardHeight = keyboardFrame.height

        inputContainerBottomConstraint.constant = -keyboardHeight

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        inputContainerBottomConstraint.constant = 0

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - UITableViewDelegate & DataSource
extension ChatDetailViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.identifier, for: indexPath) as? MessageCell else {
            return UITableViewCell()
        }
        let message = messages[indexPath.row]
        cell.configure(with: message)
        return cell
    }
}

// MARK: - MessageManagerDelegate
extension ChatDetailViewController: MessageManagerDelegate {

    func messageManager(_ manager: MessageManager, didUpdateChats chats: [Chat]) {
        loadMessages()
        scrollToBottom(animated: true)
    }

    func messageManager(_ manager: MessageManager, didUpdateSelectedChat chat: Chat?) {
        if let updatedChat = chat, updatedChat.id == self.chat.id {
            self.chat = updatedChat
            loadMessages()
        }
    }

    func messageManager(_ manager: MessageManager, didUpdateConnectionStatus isConnected: Bool, isSocketConnected: Bool) {
        updateStatusBanner()
    }

    func messageManager(_ manager: MessageManager, didReceiveError message: String) {
        // Could show a toast or alert here
        print("Error: \(message)")
    }
}
