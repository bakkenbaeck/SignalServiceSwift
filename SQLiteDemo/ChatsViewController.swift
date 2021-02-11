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

    let igorPhoneContact = SignalAddress(name: "0x94b7382e8cbd02fc7bfd2e233e42b778ac2ce224", deviceId: 1)
    let ellenContact = SignalAddress(name: "0xc0086796cbba5b4d97cc58d175b37c758975aef1", deviceId: 1)

    lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm dd/mm/yyyy"

        return dateFormatter
    }()

    let teapot = Teapot(baseURL: URL(string: "https://token-chat-service-development.herokuapp.com")!)

    lazy var signalClient: SignalClient = {
        let client = SignalClient(baseURL: self.teapot.baseURL, recipientsDelegate: self, persistenceStore: self.persistenceStore)
        client.store.chatDelegate = self

        return client
    }()

    var persistenceStore = FilePersistenceStore()

    var chats: [SignalChat] = []

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
            self.chats = self.signalClient.store.retrieveAllChats()

        } else {
            self.user = User(privateKey: "0989d7b7ccfe3baf39ed441d001df834173e0729916210d14f60068d1d22c595")

            super.init(coder: aDecoder)

            self.register(user: self.user)
        }

        self.signalClient.store.chatDelegate = self
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let destination = segue.destination as? MessagesViewController,
            let indexPath = sender as? IndexPath else {
            fatalError()
        }

        destination.chat = self.chats[indexPath.row]
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
                    self.chats = self.signalClient.store.retrieveAllChats()

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
                fatalError(error.localizedDescription)
            }
        }
    }

    @IBAction func didTapCreateChatButton(_ sender: Any) {
        // Group message test
//        self.signalClient.sendGroupMessage("", type: .new, to: [self.testContact, self.otherContact, self.ellenContact, self.user.address])
//        // 1:1 chat test.
        let chat = self.signalClient.store.fetchOrCreateChat(with: self.igorPhoneContact.name)
        self.didRequestSendRandomMessage(in: chat)
    }
}

extension ChatsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.chats.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ChatCell

        self.configureCell(cell, at: indexPath)

        return cell
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    private func configureCell(_ cell: ChatCell, at indexPath: IndexPath) {
        let chat = self.chats[indexPath.row]
        cell.title = chat.displayName
        cell.avatarImage = chat.image

        if let message = chat.visibleMessages.last {
            cell.date = self.dateFormatter.string(from: Date(milisecondTimeIntervalSinceEpoch: message.timestamp))
        }
    }
}

extension ChatsViewController: SignalServiceStoreChatDelegate {
    func signalServiceStoreWillChangeChats() {
        self.tableView.beginUpdates()
    }

    func signalServiceStoreDidChangeChat(_ chat: SignalChat, at indexPath: IndexPath, for changeType: SignalServiceStore.ChangeType) {
        switch changeType {
        case .delete:
            self.chats.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
        case .insert:
            self.chats.insert(chat, at: indexPath.row)
            self.tableView.insertRows(at: [indexPath], with: .right)
        case .update:
            self.chats.remove(at: indexPath.row)
            self.chats.insert(chat, at: indexPath.row)
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }
    }

    func signalServiceStoreDidChangeChats() {
        self.tableView.endUpdates()
    }
}

extension ChatsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "chat", sender: indexPath)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}

extension ChatsViewController: MessagesViewControllerDelegate {
    static func randomMessage() -> (String, [UIImage]) {
        let messages: [(String, [UIImage])] = [
            (SofaMessage(body: "This is testing message from our SignalClient.").content, []),
            (SofaMessage(body: "This is random message from SQLite demo.").content, []),
            (SofaMessage(body: "What's up, doc?.").content, [UIImage(named: "doc")!]),
            (SofaMessage(body: "This is Ceti Alpha 5!!!!!!!").content, [UIImage(named: "cetialpha5")!]),
            (SofaMessage(body: "Hey, this is a test with a slightly longer text, and some utf-32 characters as well. 👨‍👩‍👧☺️😇 Am I right? 👨🏿‍🔬. I am right…").content, [])
        ]

        let index = Int(arc4random() % UInt32(messages.count))

        return messages[index]
    }

    func didRequestSendRandomMessage(in chat: SignalChat) {
        let (body, images) = ChatsViewController.randomMessage()
        let attachments = images.compactMap { img in img.pngData() }

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
        if address == "0x94b7382e8cbd02fc7bfd2e233e42b778ac2ce224" {
            return "Igor iPhone X"
        } else if address == "0xcc4886677b6f60e346fe48968189c1b1fe9f3b33" {
            return "Simulator X"
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
