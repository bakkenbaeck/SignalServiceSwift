//
//  MessagesViewController.swift
//  SQLiteDemo
//
//  Created by Igor Ranieri on 20.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import SignalServiceSwift
import SweetUIKit
import UIKit

extension UIColor {
    static var darkGreen: UIColor {
        return #colorLiteral(red: 0.02588345483, green: 0.7590896487, blue: 0.2107430398, alpha: 1)
    }

    static var lightGray: UIColor {
        return #colorLiteral(red: 0.9254434109, green: 0.925465405, blue: 0.9339957833, alpha: 1)
    }
}

extension CGFloat {
    /// The height of a single pixel on the screen.
    static var lineHeight: CGFloat {
        return 1 / UIScreen.main.scale
    }
}

protocol MessagesViewControllerDelegate {
    func didRequestSendRandomMessage(in chat: SignalChat)
}

class MessagesViewController: UIViewController {

    var chat: SignalChat!

    var shouldScrollToBottom = false 

    lazy var messages: [SignalMessage] = {
        return self.chat.visibleMessages
    }()

    var delegate: MessagesViewControllerDelegate?

    private lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)

        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.estimatedRowHeight = 64.0
        // view.scrollsToTop = false
        view.dataSource = self
        view.delegate = self
        view.separatorStyle = .none
        view.keyboardDismissMode = .interactive
        view.contentInsetAdjustmentBehavior = .never

        view.register(UITableViewCell.self)
        view.register(MessagesTextCell.self)
        view.register(StatusCell.self)

        return view
    }()

    lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm dd/MM/yyyy"

        return dateFormatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = self.chat.displayName

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send random", style: .plain, target: self, action: #selector(self.sendRandomMessage(_:)))

        self.addSubviewsAndConstraints()

        self.shouldScrollToBottom = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.tableView.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.scrollTableViewToBottom(animated: false)
        self.tableView.isHidden = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if self.shouldScrollToBottom {
            self.shouldScrollToBottom = false
            self.scrollTableViewToBottom(animated: true)
        }
    }

    private func scrollTableViewToBottom(animated: Bool) {
        guard !self.messages.isEmpty else { return }

        let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
        self.tableView.scrollToRow(at: indexPath, at: .none, animated: animated)
    }

    private func addSubviewsAndConstraints() {
        self.view.addSubview(self.tableView)

        self.tableView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        self.tableView.left(to: self.view)
        self.tableView.right(to: self.view)
        self.tableView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }

    @objc func sendRandomMessage(_ sender: Any) {
        self.shouldScrollToBottom = true
        self.delegate?.didRequestSendRandomMessage(in: self.chat)
    }

    private func message(at indexPath: IndexPath) -> SignalMessage {
        return self.messages[indexPath.row]
    }
}

extension MessagesViewController: UITableViewDelegate {

}

extension MessagesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.configuredCell(for: indexPath)

        return cell
    }

    private func configuredCell(for indexPath: IndexPath) -> UITableViewCell {
        let message = self.message(at: indexPath)

        if let message = message as? InfoSignalMessage {
            let cell = self.tableView.dequeue(StatusCell.self, for: indexPath)
            let localizedFormat = NSLocalizedString(message.customMessage, comment: "")
            let contact = ContactManager.displayName(for: message.senderId)
            let string = String(format: localizedFormat, contact, message.additionalInfo)

            let attributed = NSMutableAttributedString(string: string)
            attributed.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: (string as NSString).range(of: contact))
            attributed.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: (string as NSString).range(of: message.additionalInfo))

            cell.textLabel?.attributedText = attributed

            return cell
        } else {
            let cell = self.tableView.dequeue(MessagesTextCell.self, for: indexPath)
            cell.isOutgoingMessage = message is OutgoingSignalMessage
            cell.messageBody = SofaMessage(content: message.body).body

            //cell.sentState = (message as? OutgoingSignalMessage)?.messageState ?? .none
            //cell.text = self.dateFormatter.string(from: Date(milisecondTimeIntervalSinceEpoch: message.timestamp))

            if let attachment = message.attachment, let image = UIImage(data: attachment) {
                cell.messageImage = image
            } else {
                cell.messageImage = nil
            }

            return cell
        }
    }
}

extension MessagesViewController: SignalServiceStoreMessageDelegate {
    func signalServiceStoreWillChangeMessages() {
        self.tableView.beginUpdates()
    }

    func signalServiceStoreDidChangeMessage(_ message: SignalMessage, at indexPath: IndexPath, for changeType: SignalServiceStore.ChangeType) {
        guard message.chatId == self.chat.uniqueId else { return }

        switch changeType {
        case .insert:
            (message as? IncomingSignalMessage)?.isRead = true
            self.messages.append(message)
            self.tableView.insertRows(at: [indexPath], with: .middle)
        case .delete:
            self.tableView.deleteRows(at: [indexPath], with: .right)
        case .update:
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }
    }

    func signalServiceStoreDidChangeMessages() {
        self.tableView.endUpdates()

        if self.shouldScrollToBottom {
            self.shouldScrollToBottom = false
            self.scrollTableViewToBottom(animated: true)
        }
    }
}
