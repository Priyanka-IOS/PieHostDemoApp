//
//  MessageCell.swift
//  PieHostDemoApp
//
//   Created by Priyanka Ghosh on 28/11/25.
//

import UIKit

// MARK: - MessageCell
class MessageCell: UITableViewCell {

    static let identifier = "MessageCell"

    private let bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        bubbleView.addSubview(messageLabel)
        contentView.addSubview(bubbleView)
        contentView.addSubview(timestampLabel)

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),

            timestampLabel.topAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: 4),
            timestampLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 4),
            timestampLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    func configure(with message: Message) {
        messageLabel.text = message.text
        timestampLabel.text = message.timestamp.formattedTime

        if message.isSentByUser {
            // Sent message (right aligned, blue)
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true

            if message.isQueued {
                bubbleView.backgroundColor = .systemOrange
                messageLabel.textColor = .white
            } else {
                bubbleView.backgroundColor = .systemBlue
                messageLabel.textColor = .white
            }
        } else {
            // Received message (left aligned, gray)
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
            bubbleView.backgroundColor = .systemGray5
            messageLabel.textColor = .label
        }
    }
}
