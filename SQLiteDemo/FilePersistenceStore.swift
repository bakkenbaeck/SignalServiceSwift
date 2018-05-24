//
//  FilePersistenceStore.swift
//  Demo
//
//  Created by Igor Ranieri on 19.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import Foundation
import SignalServiceSwift
import SQLite

class FilePersistenceStore: PersistenceStore {

    let dbConnection: Connection

    let table: Table
    
    let typeField: Expression<String>
    let dataField: Expression<Data>
    let identifierField: Expression<String>
    let foreignKeyField: Expression<String?>
    let idField: Expression<Int64>

    init() {
        let libPath = FileManager.default.urls(for: FileManager.SearchPathDirectory.libraryDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first!

        // If this crashes, we've messed up the file path.
        self.dbConnection = try! Connection(libPath.absoluteString.appending("db.sqlite3"))

        self.table = Table("objects")
        self.idField = Expression<Int64>("id")
        self.identifierField = Expression<String>("uuid")
        self.dataField = Expression<Data>("data")
        self.typeField = Expression<String>("type")
        self.foreignKeyField = Expression<String?>("foreignKey")

        _ = try? self.dbConnection.run(self.table.create { t in
            t.column(self.idField, primaryKey: true)
            t.column(self.identifierField)
            t.column(self.dataField)
            t.column(self.typeField)
            t.column(self.foreignKeyField)
            t.unique(self.identifierField, self.typeField)
        })

        NSLog("Did finish database setup.")
    }

    func retrieveUser() -> User? {
        var user: User? = nil
        let result = self.table.filter(self.typeField == "user").select(self.dataField)

        do {
            if let row = try self.dbConnection.pluck(result) {
                let data = row[self.dataField]
                user = try! JSONDecoder().decode(User.self, from: data)
                NSLog("Did retrieve user from DB.")
            }
        } catch (let error) {
            NSLog(error.localizedDescription)
        }

        return user
    }

    func storeUser(_ user: User) {
        let key = user.toshiAddress
        let data = try! JSONEncoder().encode(user)
        let insert = self.table.insert(self.identifierField <- key, self.dataField <- data, self.typeField <- "user")

        do {
            try self.dbConnection.run(insert)
            NSLog("Did persist new user.")
        } catch (let error) {
            print(error)
        }
    }

    func retrieveAllObjects(ofType type: SignalServiceStore.PersistedType, range: Range<Int>?, foreignKey: String?) -> [Data] {
        let result: Table

        if let foreignKey = foreignKey {
            result = self.table.filter(self.typeField == type.rawValue && self.foreignKeyField == foreignKey)
        } else {
            result = self.table.filter(self.typeField == type.rawValue)
        }

        var objects = [Data]()

        do {
            for row in try self.dbConnection.prepare(result.limit(range?.upperBound ?? .max, offset: range?.lowerBound ?? 0)) {
                objects.append(row[self.dataField])
            }
        } catch (let error) {
            NSLog("Could not retrieve data from db: %@", error.localizedDescription)
        }

        return objects
    }

    func retrieveObject(ofType type: SignalServiceStore.PersistedType, key: String, foreignKey: String?) -> Data? {
        let result = self.table.filter(self.typeField == type.rawValue && self.identifierField == key)
        var object: Data?

        do {
            object = try self.dbConnection.pluck(result)?[self.dataField]
        } catch (let error) {
            NSLog("Could not retrieve data from db: %@", error.localizedDescription)
        }

        return object
    }

    func update(_ data: Data, key: String, type: SignalServiceStore.PersistedType) {
        let object = self.table.filter(self.identifierField == key && self.typeField == type.rawValue)

        do {
            try self.dbConnection.run(object.update(self.dataField <- data))
        } catch (let error) {
            NSLog("Failed to update data in the db: %@", error.localizedDescription)
        }
    }

    func store(_ data: Data, key: String, foreignKey: String?, type: SignalServiceStore.PersistedType) {
        let insert = self.table.insert(self.identifierField <- key, self.foreignKeyField <- foreignKey, self.dataField <- data, self.typeField <- type.rawValue)

        do {
            try self.dbConnection.run(insert)
        } catch (let error as SQLite.Result) {
            if case SQLite.Result.error(let message, let code, _) = error {
                if code == 19 {
                    // Code 19 means we're violating the unique key constraint.
                    // In that case, we're regenerating data, and would rather keep the new one
                    // so we attempt to override it instead, by first deleting the outdated version
                    // and calling ourselves again. 😬
                    if self.deleteValue(key: key, type: type) {
                        self.store(data, key: key, foreignKey: foreignKey, type: type)
                    } else {
                        NSLog("Failed to delete library data in the db: %@", message)
                    }
                } else {
                    NSLog("Failed to store library data in the db: %@", message)
                }
            }
        } catch (let error) {
            NSLog("Failed to store data in the db: %@", error.localizedDescription)
        }
    }

    func deleteValue(key: String, type: SignalServiceStore.PersistedType) -> Bool {
        let result: Bool

        let delete = self.table.filter(self.identifierField == key && self.typeField == type.rawValue)
        do {
            result = try self.dbConnection.run(delete.delete()) > 0
        } catch (let error) {
            NSLog("Failed to delete data in the db: %@", error.localizedDescription)
            result = false
        }

        return result
    }
}

extension FilePersistenceStore: SignalLibraryStoreDelegate {
    func deleteSignalLibraryValue(key: String, type: SignalLibraryStore.LibraryStoreType)  -> Bool {
        let result: Bool
        let delete = self.table.filter(self.identifierField == key && self.typeField == type.rawValue)
        do {
            result = try self.dbConnection.run(delete.delete()) > 0
        } catch (let error) {
            result = false
            NSLog("Failed to delete data in the db: %@", error.localizedDescription)
        }

        return result
    }

    func storeSignalLibraryValue(_ data: Data, key: String, type: SignalLibraryStore.LibraryStoreType) {
        let insert = self.table.insert(self.identifierField <- key, self.dataField <- data, self.typeField <- type.rawValue)

        do {
            try self.dbConnection.run(insert)
        } catch (let error as SQLite.Result) {
            if case SQLite.Result.error(let message, let code, _) = error {
                if code == 19 {
                    // Code 19 means we're violating the unique key constraint.
                    // In that case, we're regenerating data, and would rather keep the new one
                    // so we attempt to override it instead, by first deleting the outdated version
                    // and calling ourselves again. 😬
                    if self.deleteSignalLibraryValue(key: key, type: type) {
                        self.storeSignalLibraryValue(data, key: key, type: type)
                    } else {
                        NSLog("Failed to delete library data in the db: %@", message)
                    }
                } else {
                    NSLog("Failed to store library data in the db: %@", message)
                }
            }
        } catch {
            NSLog("Failed to store library data in db with unknown error")
        }
    }

    func retrieveSignalLibraryValue(key: String, type: SignalLibraryStore.LibraryStoreType) -> Data? {
        let result = self.table.filter(self.typeField == type.rawValue && self.identifierField == key)
        var object: Data?

        do {
            object = try self.dbConnection.pluck(result)?[self.dataField]
        } catch (let error) {
            NSLog("Could not retrieve data from db: %@", error.localizedDescription)
        }

        return object
    }

    func retrieveAllSignalLibraryValue(ofType type: SignalLibraryStore.LibraryStoreType) -> [Data] {
        let result = self.table.filter(self.typeField == type.rawValue)
        var objects = [Data]()

        do {
            for row in try self.dbConnection.prepare(result) {
                objects.append(row[self.dataField])
            }
        } catch (let error) {
            NSLog("Could not retrieve data from db: %@", error.localizedDescription)
        }

        return objects
    }
}
