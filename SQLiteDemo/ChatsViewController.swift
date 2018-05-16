//
//  ChatsViewController.swift
//  SQLiteDemo
//
//  Created by Igor Ranieri on 20.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import EtherealCereal
import SignalServiceSwift
import Teapot
import UIKit

extension String {
    enum TruncationPosition {
        case head
        case middle
        case tail
    }

    func truncated(limit: Int, position: TruncationPosition = .tail, leader: String = "…") -> String {
        guard self.count > limit else { return self }

        switch position {
        case .head:
            return leader + self.suffix(limit)
        case .middle:
            let headCharactersCount = Int(ceil(Float(limit - leader.count) / 2.0))

            let tailCharactersCount = Int(floor(Float(limit - leader.count) / 2.0))

            return "\(self.prefix(headCharactersCount))\(leader)\(self.suffix(tailCharactersCount))"
        case .tail:
            return self.prefix(limit) + leader
        }
    }
}

class ChatsViewController: UIViewController {
    let user: User

    let testContact = SignalAddress(name: "0x2b307303d6ecca8ced81542518266ff7794b27fc", deviceId: 1)
    let otherContact = SignalAddress(name: "0x10e300f7eac54d7d12ff0ce3063cb942afd8d25f", deviceId: 1)
    let ellenContact = SignalAddress(name: "0xc0086796cbba5b4d97cc58d175b37c758975aef1", deviceId: 1)

    lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm dd/mm/yyyy"

        return dateFormatter
    }()

    let teapot = Teapot(baseURL: URL(string: "https://chat.internal.service.toshi.org")!)

    lazy var signalClient: SignalClient = {
        let client = SignalClient(baseURL: URL(string: "https://chat.internal.service.toshi.org")!, recipientsDelegate: self, persistenceStore: self.persistenceStore)
        client.store.chatDelegate = self

        return client
    }()

    var persistenceStore = FilePersistenceStore()

    @IBOutlet var tableView: UITableView!

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        fatalError()
    }

    required init?(coder aDecoder: NSCoder) {
        if let user = self.persistenceStore.retrieveUser() {
            self.user = user

            super.init(coder: aDecoder)

            self.signalClient.startSocket()
            self.signalClient.shouldKeepSocketAlive = true
        } else {
            self.user = User(privateKey: "0989d7b7ccfe3baf39ed441d001df834173e0729916210d14f60068d1d22c595")

            super.init(coder: aDecoder)

            self.register(user: self.user)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destination = segue.destination as? MessagesViewController,
            let indexPath = sender as? IndexPath else {
            fatalError()
        }

        destination.chat = self.signalClient.store.chat(at: indexPath.row)
        destination.delegate = self

        self.signalClient.store.messageDelegate = destination
    }

    func register(user: User) {
        self.fetchTimestamp { timestamp in
            let payload = self.signalClient.generateUserBootstrap(username: user.toshiAddress, password: user.password)
            let path = "/v1/accounts/bootstrap"

            guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
                NSLog("Invalid JSON payload!")
                return
            }

            let payloadString = String(data: data, encoding: .utf8)!

            let hashedPayload = user.cereal.sha3(string: payloadString)
            let message = "PUT\n\(path)\n\(timestamp)\n\(hashedPayload)"
            let signature = "0x\(user.cereal.sign(message: message))"

            let fields: [String: String] = ["Token-ID-Address": user.cereal.address, "Token-Signature": signature, "Token-Timestamp": String(timestamp)]
            let requestParameter = RequestParameter(payload)

            self.teapot.put(path, parameters: requestParameter, headerFields: fields) { result in
                switch result {
                case .success(_, let response):
                    guard response.statusCode == 204 else {
                        fatalError()
                    }

                    self.signalClient.startSocket()
                    self.signalClient.shouldKeepSocketAlive = true
                    self.persistenceStore.storeUser(user)

                case .failure(_, _, let error):
                    NSLog(error.localizedDescription)
                    break
                }
            }
        }
    }

    func fetchTimestamp(_ completion: @escaping ((Int) -> Void)) {
        self.teapot.get("/v1/accounts/bootstrap/") { (result: NetworkResult) in
            switch result {
            case .success(let json, let response):
                guard response.statusCode == 200 else { fatalError("Could not retrieve timestamp from chat service.") }
                guard let json = json?.dictionary else { fatalError("JSON dictionary not found in payload") }
                guard let timestamp = json["timestamp"] as? Int else { fatalError("Timestamp not found in json payload or not an integer.") }

                DispatchQueue.main.async {
                    completion(timestamp)
                }
            case .failure(_, _, let error):
                NSLog(error.localizedDescription)
            }
        }
    }

    @IBAction func didTapCreateChatButton(_ sender: Any) {
        // Group message test
        self.signalClient.sendGroupMessage("", type: .new, to: [self.testContact, self.otherContact, self.ellenContact, self.user.address])
//        // 1:1 chat test.
//        let chat = self.signalClient.store.fetchOrCreateChat(with: self.ellenContact.name)
//        self.didRequestSendRandomMessage(in: chat)
    }
}

extension ChatsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.signalClient.store.numberOfChats
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ChatCell

        self.configureCell(cell, at: indexPath)

        return cell
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        let cell = ChatCell()
//        self.configureCell(cell, at: indexPath)
//
//        cell.layoutIfNeeded()
//
//        return cell.systemLayoutSizeFitting(CGSize(width: self.tableView.bounds.width, height: .greatestFiniteMagnitude), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
//    }

    private func configureCell(_ cell: ChatCell, at indexPath: IndexPath) {
        let chat = self.signalClient.store.chat(at: indexPath.row)!
        cell.title = chat.displayName
        cell.avatarImage = chat.image

        if let message = chat.visibleMessages.last {
            cell.date = self.dateFormatter.string(from: Date(milisecondTimeIntervalSinceEpoch: message.timestamp))
        }
    }
}

extension ChatsViewController: SignalServiceStoreChatDelegate {
    func signalServiceStoreWillChangeChats() {
    }

    func signalServiceStoreDidChangeChat(_ chat: SignalChat, at indexPath: IndexPath, for changeType: SignalServiceStore.ChangeType) {
    }

    func signalServiceStoreDidChangeChats() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}

extension ChatsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "chat", sender: indexPath)
    }
}

extension ChatsViewController: MessagesViewControllerDelegate {
    static func randomMessage() -> (String, [UIImage]) {
        let messages: [(String, [UIImage])] = [
            (SofaMessage(body: "This is testing message from our SignalClient.").content, []),
            (SofaMessage(body: "This is random message from SQLite demo.").content, []),
            (SofaMessage(body: "What's up, doc?.").content, [#imageLiteral(resourceName: "doc")]),
            (SofaMessage(body: "This is Ceti Alpha 5!!!!!!!").content, [#imageLiteral(resourceName: "cetialpha5")]),
            (SofaMessage(body: "Hey, this is a test with a slightly longer text, and some utf-32 characters as well. 👨‍👩‍👧☺️😇 Am I right? 👨🏿‍🔬. I am right…").content, [])
        ]

        let index = Int(arc4random() % UInt32(messages.count))

        return messages[index]
    }

    func didRequestSendRandomMessage(in chat: SignalChat) {
        let (body, images) = ChatsViewController.randomMessage()
        let attachments = images.compactMap { img in UIImagePNGRepresentation(img) }

        if chat.isGroupChat {
            self.signalClient.sendGroupMessage(body, type: .deliver, to: chat.recipients!, attachments: attachments)
        } else {
            self.signalClient.sendMessage(body, to: chat.recipients!.first!, in: chat, attachments: attachments)
        }
    }
}

extension ChatsViewController: SignalRecipientsDisplayDelegate {
    func displayName(for address: String) -> String {
       return ContactManager.displayName(for: address)
    }

    func image(for address: String) -> UIImage? {
        return nil
    }
}

class ContactManager {
    static func displayName(for address: String) -> String {
        if address == "0x2b307303d6ecca8ced81542518266ff7794b27fc" {
            return "Toshi iPhone X"
        } else if address == "0xd102af8bf76e8d438a44e23bc83ea3ac8f53f2c7" {
            return "Toshi SE"
        } else if address == "0xc0086796cbba5b4d97cc58d175b37c758975aef1" {
            return "Ellen"
        } else {
            return address.truncated(limit: 8, leader: "")
        }
    }

    static func image(for address: String) -> UIImage? {
        return nil
    }
}
