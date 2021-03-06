//
//  QuantumDB.swift
//  fatmind
//
//  Created by Rix on 4/20/16.
//  Copyright © 2016 bitcore. All rights reserved.
//
import UIKit
import Foundation

class QuantumDB {
    var service = APIService()
    let userDefaults:UserDefaults!
    var db: OpaquePointer? = nil
    
    init(){
        //initalize user defaults
        //  data
        //   databaseImported   bool   - true or false to show if inital data was imported - this only happens once
        //   dateLastDatabaseImported  string  - stores the date of the last import
        userDefaults = UserDefaults.standard
    }

    //MARK: SQLite DB Creation Functions
    public func openDB() -> Bool {
        
        if sqlite3_open(dataFilePath(), &db) == SQLITE_OK {
            print("connected to db")
            
            if !userDefaults.bool(forKey: "hasLaunchedOnce") {
                self.userDefaults.set(true, forKey: "hasLaunchedOnce")
                self.userDefaults.set(1, forKey: "counterSync")
                self.userDefaults.set(1, forKey: "clientCounterLastSync")
                self.userDefaults.set(0, forKey: "serverCounterLastSync")
                //self.setDateLastImportUserDefault(0.0)
                //self.setDateLastSyncToServerUserDefault(withSecondsToAdd: 0.0)
                print("user defaults set")

                if createDB() {
                    print("database created")
                    return true
                } else {
                    self.userDefaults.set(false, forKey: "hasLaunchedOnce")
                    return false
                }
            } else {
                print("DB aleady created")
                return true
            }
        } else {
            sqlite3_close(db)
            print("Failed to open database")
            return false
        }
        
    }
    
    public func createDB() -> Bool {
        return createTable() && createFTSTable() && createTrigger()
    }
    
    private func createTable() -> Bool {
        
        let createSQL = "CREATE TABLE IF NOT EXISTS quantum(" +
            "id TEXT," +
            "note TEXT, date_created TEXT, date_updated TEXT," +
            "updated INT, deleted INT, new INT, counter_sync INT);"
    
        return sqlite3Exec(sqlCommand: createSQL, description: "quantum table")
        
    }
    
    private func createFTSTable() -> Bool {
        
        let createSQL = "CREATE VIRTUAL TABLE qfts USING fts4(content=\"quantum\", id, note);"

        return sqlite3Exec(sqlCommand: createSQL, description: "qfts table")
        
    }
    
    private func createTrigger() -> Bool {
        
        let createSQL1 = "CREATE TRIGGER IF NOT EXISTS quantum_bu BEFORE UPDATE ON quantum BEGIN" +
            "  DELETE FROM qfts WHERE docid=old.rowid;" +
            "END;"
        
        let createSQL2 = "CREATE TRIGGER IF NOT EXISTS quantum_bd BEFORE DELETE ON quantum BEGIN" +
            "  DELETE FROM qfts WHERE docid=old.rowid;" +
            "END;"
        
        let createSQL3 = "CREATE TRIGGER IF NOT EXISTS quantum_au AFTER UPDATE ON quantum BEGIN" +
            "  INSERT INTO qfts(docid, note) VALUES(new.rowid, new.note);" +
            "END;"

        let createSQL4 = "CREATE TRIGGER IF NOT EXISTS quantum_ai AFTER INSERT ON quantum BEGIN" +
            "  INSERT INTO qfts(docid, note) VALUES(new.rowid, new.note);" +
            "END;"
        
        let triggerResult = sqlite3Exec(sqlCommand: createSQL1, description: "trigger") && sqlite3Exec(sqlCommand: createSQL2, description: "trigger") && sqlite3Exec(sqlCommand: createSQL3, description: "trigger") && sqlite3Exec(sqlCommand: createSQL4, description: "trigger")
        
        return triggerResult
        
    }

    private func sqlite3Exec(sqlCommand sql: String, description desc: String) -> Bool{

        var errMsg:UnsafeMutablePointer<Int8>? = nil
        
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let error = String(cString: errMsg!)
            print("Failed to create \(desc). \(error)")
            return false
        } else {
            print("Successfully created \(desc)")
            return true
        }

    }
    
    private func dataFilePath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(
            FileManager.SearchPathDirectory.documentDirectory,
            FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentsDirectory = paths[0] as NSString
        return documentsDirectory.appendingPathComponent("data.sqlite") as String
    }
    
    //MARK: Syncing Functions
    
    public func mainSync(_ callback: @escaping (Bool) -> ()) {
        
        self.syncFromServer {
        (status) in
            print("AppDelegate.swift: quantumDB.syncFromServer return status - \(status)")
            if status {
                self.syncToServer {
                    (status) in
                    if status {
                        print("AppDelegate.swift: status of run quantumDB.syncToServer  call - \(status)")
                        callback(true)
                    } else {
                        callback(false)
                    }
                }
            } else {
                callback(false)
            }
        }
        
    }
        
    //loads quantum changes from API service
    public func syncFromServer(_ callback: @escaping (Bool) -> ()) {
        print("QuantumDB.swift: running function syncFromServer in QuantumDB")
        //get the date of last data import
        //copy new quantum from local SQLite DB to Master DB
        print("QuantumDB.swift: running function service.getSyncFromServer in APIService.swift")
        service.getSyncFromServer(byServerSyncCounter: self.getServerCounterSyncLocal()) {
            (statusCode, response) in
            
            //    print("data returned from getDataAfterDate fucntion in QuantumDB \(response["data"]! as! NSArray)")
            //check if api call was successful
            if statusCode == 200 {
                //convert data from API JSON data into NSArrays
                if let quantums = response["data"] as? NSArray {
                    print("QuantumDB.swift: number of quantums found \(quantums.count)")
                    if quantums.count > 0 {
                        //Load NSArray of Quantums into SQLite DB
                        print(quantums)
                        
                        self.syncInsertUpdateDataToDB(withNSArray: quantums)
                        self.userDefaults.set(true, forKey: "databaseImported")
                        print("QuantumDB.swift: running function service.getServerCounterLastSync from APIService.swift")
                        self.service.getServerCounterLastSync{
                            (statusCode, response) in
                            print("service.getServerCounterLastSync response")
                            print(response)
                            if let counter = response["data"] as? NSDictionary {
                                print("this is the counter inside syncFromServer")
                                if let count =  counter["counter"] as? Int {
                                    self.setServerCounterSync(withCounter: count)
                                }
                                
                            } else {
                                print("service.getServerCounterLastSync response error")
                            }
                            
                        }

                    }
                   
                }
                callback(true)
            } else {
               
                callback(false)
            }
        }
    }

    //queries all local changes and sends to server
    public func syncToServer(_ callback: @escaping (Bool) -> ()) {

        let qList = self.getLocalChanges()
        
        service.postSyncToServer(withQuantumList: qList) {
            (statusCode, response) in
            
            print(response["message"]!)
            print("update file sent to master db")
            self.setClientCounterLastSync()
            callback(true)
            
        }
        callback(true)

    }
    
    //Function decides if quantum should be inserted or updated
    // Takes a nsarray of quantums and casts it to a Quantum Object
    // Checks if Quantum is in the local sqlite db
    public func syncInsertUpdateDataToDB(withNSArray data: NSArray){
        print("called syncInsertUpdateDataToDB")
        
        for q in data {
            
            let quantum: Quantum
            
            //cast or parse quanta into proper format
            if q is Quantum {
                quantum = q as! Quantum
            } else {
                quantum = Quantum(data: q as AnyObject)!
            }
            
            if self.checkIfQuantumExistsInLocalDB(withQuantum: quantum) {
                self.updateQuantumInLocalDB(withQuantum: quantum)
            } else {
                self.insertQuantumToLocalDB(withQuantum: quantum)
            }
            
        }
    }
    

    // MARK: - SQLite DB Functions
    
    public func getLocalChanges() -> [Quantum] {
        print("QuantumDB - getLocalChanges() function call")
        var quantumList = [Quantum]()
        
        var queryStatement: OpaquePointer? = nil
        let queryStatementString = "SELECT id, note, deleted, counter_sync FROM quantum" +
        " WHERE counter_sync >= ?;"
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            
            //sqlite3_bind_text(queryStatement, 1, (self.getSyncDateToString() as NSString).utf8String, -1, nil)
            sqlite3_bind_int(queryStatement, 1, Int32(self.getClientCounterSync()))

            var id = ""
            var note = ""
            var deleted : Int32 = 0
            var counter : Int32 = 0
            
            while (sqlite3_step(queryStatement) == SQLITE_ROW) {
                
                if let queryResult0 = sqlite3_column_text(queryStatement, 0) {
                    id = String(cString: queryResult0)
                } else {
                    id = ""
                }
                
                if let queryResult1 = sqlite3_column_text(queryStatement, 1) {
                    note = String(cString: queryResult1)
                } else {
                    note = ""
                }
                
                deleted = sqlite3_column_int(queryStatement, 2)

                counter = sqlite3_column_int(queryStatement, 3)

                let loadQ = Quantum(id: id, userID: nil, note: note, dateCreated: nil, dateUpdated: nil, deleted: false, counterSync: 0)
                
                quantumList.append(loadQ)
                
                print("Query Result from getLocalChange - syncToServer:")
                print("\(id) | \(note) | counter: \(counter) | \(deleted)")
                
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
    
        return quantumList
    
    }
    
    
    //  print all quamtum to console
    public func getAllQuantum() -> [Quantum] {
        print("PRINTING ALL QUANTUM TO CONSOLE:")

        var quantumList = [Quantum]()
        
        var queryStatement: OpaquePointer? = nil
        let queryStatementString = "SELECT id, note, date_created FROM quantum ORDER BY date_created DESC;"
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            
            var id = ""
            var note = ""
            var dateCreated = ""
            
            while (sqlite3_step(queryStatement) == SQLITE_ROW) {
                
                if let queryResult0 = sqlite3_column_text(queryStatement, 0) {
                    id = String(cString: queryResult0)
                } else {
                    id = ""
                }
                
                if let queryResult1 = sqlite3_column_text(queryStatement, 1) {
                    note = String(cString: queryResult1)
                } else {
                    note = ""
                }
                
                if let queryResult2 = sqlite3_column_text(queryStatement, 2) {
                    dateCreated = String(cString: queryResult2)
                } else {
                    dateCreated = ""
                }

            
                let loadQ = Quantum(id: id, userID: nil, note: note, dateCreated: dateCreated, dateUpdated: nil, deleted: false, counterSync: 0)
                
                quantumList.append(loadQ)
                
                print("\(id) \n \(dateCreated) \n \(note)\n\n ------------------------------------------------------")
                
                
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
        
        return quantumList
        
    }
    
    
    
    //Function takes any Quantum NSArray and inserts it into the SQLite3 DB
    //   example use - takes data from API call and loads into sqlite3 full text search virtual table
    //  this also used to load one quantum to the local db
    public func insertNewDataToDB(_ data: NSArray){
        print("called loadDataToDB")
        
        var insertStatement: OpaquePointer? = nil
        
        let insertStatementString = "INSERT INTO quantum (id, note, date_created)" +
                                    "VALUES (?, ?, ?);"
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            
            //add all data to full text virtual table
            for q in data {
                print("print q in loadDataToDB function QuantumDB.swift \(q)")
                let quantum: Quantum
                
                //cast or parse quanta into proper format
                if q is Quantum {
                    quantum = q as! Quantum
                } else {
                    quantum = Quantum(data: q as AnyObject)!
                }
                
                sqlite3_bind_text(insertStatement, 1, (quantum.id! as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 2, (quantum.note! as NSString).utf8String, -1, nil)
                sqlite3_bind_text(insertStatement, 3, (quantum.dateCreated! as NSString).utf8String, -1, nil)
                //sqlite3_bind_int(insertStatement, 4, Int32(quantum.newToInt))
                
                if sqlite3_step(insertStatement) == SQLITE_DONE {                    
                    print("Successfully inserted row.")
                } else {
                    print("Could not insert row.")
                }
                
                sqlite3_reset(insertStatement)
            }
        } else {
            print("INSERT statement could not be prepared.")
        }
        
        sqlite3_finalize(insertStatement)
    }
    

    
    //FULL TEXT search for quanta
    func fullTextSearchQuantum (_ keyword: String) -> [Quantum] {
        print("full text search called with keywork: \(keyword)")
        var quantumList = [Quantum]()
        
        var queryStatement: OpaquePointer? = nil
        
        let queryStatementString = "SELECT * FROM qfts WHERE qfts MATCH ?;"
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
        
            if sqlite3_bind_text(queryStatement, 1, (keyword.trim() as NSString).utf8String, -1, nil) == SQLITE_OK {
                print("bind successful")
            } else {
                print("bind unsuccessful")
            }
            var id = ""
            var note = ""
            let dateCreated = ""
            
            while (sqlite3_step(queryStatement) == SQLITE_ROW) {
            
                if let queryResult0 = sqlite3_column_text(queryStatement, 0) {
                    id = String(cString: queryResult0)
                } else {
                    id = ""
                }
                
                if let queryResult1 = sqlite3_column_text(queryStatement, 1) {
                    note = String(cString: queryResult1)
                } else {
                    note = ""
                }
                                
                let loadQ = Quantum(id: id, userID: nil, note: note, dateCreated: dateCreated, dateUpdated: nil, deleted: false, counterSync: 0)
                quantumList.append(loadQ)
                
                print("Query Result:")
                print("\(id) | \(note)")
                
                print("found result")
                
            }
            
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print ("error: \(errorMessage)")
            print("FTS statement could not be prepared.")
        }
        
        sqlite3_finalize(queryStatement)
        
        return quantumList
    }

    //INSERT one quantum into local Sqlite DB
    public func insertQuantumToLocalDB(withQuantum q : Quantum){
        print("called insertOneQuantumToDB")
        
        var insertStatement: OpaquePointer? = nil
        
        let insertStatementString = "INSERT INTO quantum (id, note, date_created, date_updated, counter_sync)" +
        "VALUES (?, ?, ?, ?, ?);"
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            
            //add all data to full text virtual table
            
            sqlite3_bind_text(insertStatement, 1, (q.id! as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (q.note! as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, (q.dateCreated! as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 4, (q.dateUpdated! as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 5, Int32(q.counterSync))
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("Successfully inserted row.")
            } else {
                print("Could not insert row.")
            }
            
            sqlite3_reset(insertStatement)
            
        } else {
            print("INSERT statement could not be prepared.")
        }
        
        sqlite3_finalize(insertStatement)
    }

    //UPDATE Quantum in local SQLite DB
    func updateQuantumInLocalDB(withQuantum q: Quantum) {
        
        var updateStatement: OpaquePointer? = nil
        let updateStatementString = "UPDATE quantum SET note = ?, date_updated = ?, counter_sync = ?" +
            " WHERE id = ?;"
        
        if sqlite3_prepare_v2(db, updateStatementString, -1, &updateStatement, nil) == SQLITE_OK {
          
            sqlite3_bind_text(updateStatement, 1, (q.note! as NSString).utf8String, -1, nil)
            sqlite3_bind_text(updateStatement, 2, (q.dateUpdated! as NSString).utf8String, -1, nil)
            sqlite3_bind_int(updateStatement, 3, Int32(q.counterSync))
            sqlite3_bind_text(updateStatement, 4, (q.id! as NSString).utf8String, -1, nil)
            
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("Successfully updated row.")
            } else {
                print("Could not update row.")
            }
            
            sqlite3_reset(updateStatement)
            
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print ("error: \(errorMessage)")

            print("UPDATE statement could not be prepared.")
        }
        
        sqlite3_finalize(updateStatement)
    }
    
    //DELETE new Quanta that have new field marked true
    func deleteQuantamFromLocalDB(_ q: Quantum) {
//        print("QuantumDB.swift: run deleteQuantaByIDFromLocalDB function")
//        
//        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
//        
//        //wrap it in a do catch for error catching
//        do {
//            //connect to the sqlite db
//            //let db = try Connection("\(path)/db.sqlite3")
//            
//            //quantum full text search
//            //let quantum = VirtualTable("quantum")
//            //let id = Expression<String>("id")
//            
//            //perform keyword search
//            //let quantums = quantum.filter(id == q.id!)
//            //iterate through results
////try db.run(quantums.delete())
//        } catch {
//            print("error")
//        }
    }
    
    //function that checks to see if a quantum exists in the local db
    public func checkIfQuantumExistsInLocalDB(withQuantum q: Quantum) -> Bool{
        print("checkIfQuantumExistsInLocalDB")
        print(q.id!)
        var result = false
        var queryStatement: OpaquePointer? = nil
        let queryStatementString = "SELECT * FROM quantum WHERE id = ?;"
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            
            sqlite3_bind_text(queryStatement, 1, (q.id! as NSString).utf8String, -1, nil)
            
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                print("Found item")
                result =  true
            } else {
                print("did not find item")
                result = false
            }
            
        } else {
            print("SELECT statement could not be prepared - checkIfQuantumExistsInLocalDB")
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print ("error: \(errorMessage)")

            result = false
        }
        
        sqlite3_finalize(queryStatement)
        
        return result
        
    }
    
    // MARK: - Utility Functions
    public func hasLaunchedOnce() -> Bool {
        if !userDefaults.bool(forKey: "hasLaunchedOnce") {
            self.userDefaults.set(true, forKey: "hasLaunchedOnce")
            
            //self.setDateLastImportUserDefault(0.0)
            //self.setDateLastSyncToServerUserDefault(withSecondsToAdd: 0.0)
            
            
            print("database not imported")
            return false
        } else {
            return true
        }
    }
    
    //check if initial (first time import) of data has happened
    //  stored in databaseImported user default
    public func isInitialDataLoaded() -> Bool {
        
        let isInitialLoad = userDefaults.bool(forKey: "databaseImported")
        if isInitialLoad {
            print("database WAS imported")
            return true
        } else {
            self.userDefaults.set(false, forKey: "databaseImported")
            print("database not imported")
            return false
        }
    }
    
    public func incrementCounterSync() {
        let counter = self.userDefaults.integer(forKey: "counterSync")
      
        self.userDefaults.set(counter + 1, forKey: "counterSync")
        print(counter)
    }
    
    public func incrementClientCounterSync() {
        let counter = self.userDefaults.integer(forKey: "clientCounterSync")
        
        self.userDefaults.set(counter + 1, forKey: "clientCounterSync")
        print(counter)
    }

    public func setServerCounterSync(withCounter count: Int) {
        print("setting server counter last sync")
        let counter = self.userDefaults.integer(forKey: "serverCounterLastSync")
        print("serverCounterLastSync before change \(counter)")
        self.userDefaults.set(count, forKey: "serverCounterLastSync")
        print("serverCounterLastSync after change \(count)")
    }
    
    public func setClientCounterLastSync() {
        print("setting client counter last sync")
        let counter = self.getCounterSync()
        self.userDefaults.set(counter, forKey: "clientCounterLastSync")
        print("client counter last sync set to \(counter)")
    }

    public func getCounterSync() -> Int {
        let counter = self.userDefaults.integer(forKey: "counterSync")
        
        return counter
    }
    
    
    public func getServerCounterSyncLocal() -> Int {
        let counter = self.userDefaults.integer(forKey: "serverCounterLastSync")
        
        return counter
    }
    
    public func getClientCounterSync() -> Int {
        let counter = self.userDefaults.integer(forKey: "clientCounterLastSync")
        
        return counter
    }

    
    //   MARK: TO BE DELETED
    
    //runs loading of Master DB into local SQLite DB for the first time
    // the code in this function only calls the API and loads the data into an NSArray
    // then it sends the Quantum NSArray to the loadDataToDB() function
//    public func runInitialDataLoad(_ callback: @escaping (Bool) -> ()) {
//        print("QuantumDB.swift: runInitialDataLoad Function in  QuantumDB.swift")
//        
//        //import initial data to sqlite3 full text search virtual table
//        service.getQuantamAll{
//            (statusCode, response) in
//            //print(response["data"]! as! NSArray)
//            if statusCode == 200 {
//                if let quantums = response["data"] as? NSArray {
//                    self.insertNewDataToDB(quantums)
//                    print("json load")
//                    //print(quantums)
//                }
//                print("status code erorr \(statusCode)")
//                //update user defaults
//                self.userDefaults.set(true, forKey: "databaseImported")
//                //self.setDateLastImportUserDefault(5.0)
//                // self.setDateLastSyncToServerUserDefault(withSecondsToAdd: 5.0)
//                
//                callback(true)
//            } else {
//                print("status code erorr \(statusCode)")
//                self.userDefaults.set(true, forKey: "databaseImported")
//                callback(false)
//            }
//        }
//    }
    
//    //sets the UserDefault for the Date the last time the local SQLite DB was updated from the Master DB
//    private func setDateLastImportUserDefault(_ addSeconds: Double)  {
//        //format date for API call to get new quantums since last visit
//        let dateNow = Date()
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z" //format style. Browse online to get a format that fits your needs.
//        
//        //dateFormatter.timeZone = NSTimeZone(abbreviation: "UTC");
//        //convert date to string
//        let dateNowString = dateFormatter.string(from: dateNow.addingTimeInterval(addSeconds))
//        //set the user default date
//        userDefaults.set(dateNowString, forKey: "dateLastDatabaseImported")
//    }
//    
//    //sets the UserDefault for the Date the last time the server DB was updated from iOS Device
//    private func setDateLastSyncToServerUserDefault(withSecondsToAdd addSeconds: Double)  {
//        //format date for API call to get new quantums since last visit
//        let dateNow = Date()
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z" //format style. Browse online to get a format that fits your needs.
//        
//        //dateFormatter.timeZone = NSTimeZone(abbreviation: "UTC");
//        //convert date to string
//        let dateNowString = dateFormatter.string(from: dateNow.addingTimeInterval(addSeconds))
//        //set the user default date
//        userDefaults.set(dateNowString, forKey: "dateLastSyncToServer")
//    }
//    
//    
//    
    //Function to get current date
    private func getSyncDateToString() -> String {
        //format date for API call to get new quantums since last visit
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        let dateFormatter2 = DateFormatter()
        dateFormatter2.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var date = Date()
        
        if let dateLastDatabaseImported = userDefaults.string(forKey: "dateLastDatabaseImported") {
            print("userd date first date")
            print(dateLastDatabaseImported)
            
            date = dateFormatter.date(from: dateLastDatabaseImported)!
            
        } else {
            date = Date()
        }
        
        print("getSynceDatetoString: secodn date ")
        print(dateFormatter2.string(from: date))
        
        
        //convert date to string
        return dateFormatter2.string(from: date)
        
    }
//
//    
    
//    //loads quantum changes from API service
//    public func syncFromServer(_ callback: @escaping (Bool) -> ()) {
//        print("QuantumDB.swift: running function runLoadNewData in QuantumDB")
//        //get the date of last data import
//        if let dateLastDatabaseImported = userDefaults.string(forKey: "dateLastDatabaseImported") {
//            //copy new quantum from local SQLite DB to Master DB
//            print("QuantumDB.swift: running function copyNewQuantamToMasterDB")
//            service.getSyncFromServer(withDateOfLastUpdate: dateLastDatabaseImported) {
//                (statusCode, response) in
//                
//                //    print("data returned from getDataAfterDate fucntion in QuantumDB \(response["data"]! as! NSArray)")
//                //check if api call was successful
//                if statusCode == 200 {
//                    //convert data from API JSON data into NSArrays
//                    if let quantums = response["data"] as? NSArray {
//                        print("QuantumDB.swift: quantumcount from \(quantums.count)")
//                        if quantums.count > 0 {
//                            //Load NSArray of Quantums into SQLite DB
//                            print("QuantumDB.swift: calling called APIService.getQuantumCreatedAfterDate - response there was something")
//                            print(quantums)
//                            self.syncInsertUpdateDataToDB(withNSArray: quantums)
//                        }
//                    }
//                    callback(true)
//                } else {
//                    callback(false)
//                }
//            }
//        } else {
//            //if for some reason there is no date - reset dateLastDatabaseImported user
//            //  default with current date
//            print("set new date")
//            self.setDateLastImportUserDefault(5.0)
//            callback(false)
//        }
//    }

    
    //    //runs loading of Master DB into local SQLite DB for the first time
    //    public func runInitialDataLoad(callback: (Bool) -> ()) {
    //        //import initial data to sqlite3 full text search virtual table
    //        self.getInitialData {
    //            (status) in
    //            callback(status)
    //        }
    //        //update user defaults
    //        userDefaults.setBool(true, forKey: "databaseImported")
    //        setDateLastImportUserDefault(5.0)
    //    }
    //
    //
    //    //calls API and get all quanta from database - initial data import
    //    private func getInitialData(callback:(Bool) -> ()){
    //        print("called getInitialData")
    //        service.getQuantamAll{
    //            (statusCode, response) in
    //            //print(response["data"]! as! NSArray)
    //            if statusCode == 200 {
    //                if let quantums = response["data"] as? NSArray {
    //                    self.loadDataToDB(quantums)
    //                    print("json load")
    //
    //                    //  print(quantums)
    //                }
    //                callback(true)
    //            } else {
    //                callback(false)
    //            }
    //        }
    //    }
    //   
    //    //Function takes any Quantum NSArray and inserts it into the SQLite3 DB
    //    //   example use - takes data from API call and loads into sqlite3 full text search virtual table
    //    //  this also used to load one quantum to the local db
    //    func loadDataToDB2(_ data: NSArray){
    //        print("called loadDataToDB")
    //
    //        //find directory path where sqlite is stored
    //        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    //
    //        //wrap it in a do catch for error catching
    //        do {
    //            //connect to the sqlite db
    //            let db = try Connection("\(path)/db.sqlite3")
    //
    //            //quantum full text search
    //            let quantum = VirtualTable("quantum")
    //            //try db.run(quantum.delete())
    //
    //            //create data fields
    //            let id = Expression<String>("id")
    //            let note = Expression<String>("note")
    //            let dateCreated = Expression<String>("date")
    //            let dateUpdated = Expression<String>("date_updated")
    //            let newEntry = Expression<Bool>("new")
    //            //configuration for the table
    //            let config = FTS4Config()
    //                .column(id)
    //                .column(note)
    //                .column(dateCreated)
    //                .column(dateUpdated)
    //                .column(newEntry)
    //                .tokenizer(.Porter)
    //
    //
    //            //create fts virtual table
    //            try db.run(quantum.create(.FTS4(config), ifNotExists: true))
    //
    //            //add all data to full text virtual table
    //            for q in data {
    //                print("print q in loadDataToDB function QuantumDB.swift \(q)")
    //                let quanta: Quantum
    //
    //                //cast or parse quanta into proper format
    //                if q is Quantum {
    //                    quanta = q as! Quantum
    //                } else {
    //                    quanta = Quantum(data: q as AnyObject)!
    //                }
    //
    //                //add one quanta to full text virtual table
    //                try db.run(quantum.insert(
    //                    id <- quanta.id!,
    //                    note <- quanta.note!,
    //                    dateCreated <- quanta.dateCreated!,
    //                    dateUpdated <- "",
    //                    newEntry <- quanta.new
    //                    )
    //                )
    //            }
    //        } catch {
    //            print("insertion failed: \(error)")
    //        }
    //    }
    
//    //full text search for quanta
//    func fullTextSearchQuantum (_ keyword: String) -> [Quantum] {
//        var quantumList = [Quantum]()
//        //get the path for the sqlite db
//        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
//        
//        //wrap it in a do catch for error catching
//        do {
//            //connect to the sqlite db
//            let db = try Connection("\(path)/db.sqlite3")
//            
//            //quantum full text search
//            let quantum = VirtualTable("quantum")
//            let id = Expression<String>("id")
//            let note = Expression<String>("note")
//            let dateCreated = Expression<String>("date")
//            
//            //perform keyword search
//            let quantums = quantum.filter(note.match("\(keyword.trim())"))
//            print(quantums)
//            
//            //iterate through results
//            for quanta in try db.prepare(quantums) {
//                //create Quantum Object and load it into a Quantum Array
//                let loadQ = Quantum(id: quanta[id], userID: nil, note: quanta[note], dateCreated: quanta[dateCreated], dateUpdated: nil, new: false)
//                quantumList.append(loadQ)
//                
//                print("note: \(quanta)")
//            }
//        } catch {
//            print("error")
//        }
//        
//        return quantumList
//    }
    //
    //    func updateQuantumInLocalDB(_ q: Quantum) {
    //
    //       // var quantumList = [Quantum]()
    //        //get the path for the sqlite db
    //        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    //
    //            do {
    //                //connect to the sqlite db
    //                let db = try Connection("\(path)/db.sqlite3")
    //
    //                //quantum full text search
    //                let quantum = VirtualTable("quantum")
    //                let id = Expression<String>("id")
    //                let note = Expression<String>("note")
    //                let dateUpdated = Expression<String>("date_updated")
    //           //TODO - add update date
    //                let quant = quantum.filter(id == q.id!)
    //                if try db.run(quant.update(note <- q.note!, dateUpdated <- q.dateUpdated!)) > 0 {
    //                    print("updated alice")
    //                } else {
    //                    print("alice not    found")
    //                }
    //            } catch {
    //                print("update failed: \(error)")
    //            }
    //    }
    
    
    
    //    //loads new quanta from API service
    //    public func runLoadNewData(_ callback: @escaping (Bool) -> ()) {
    //        print("QuantumDB.swift: running function runLoadNewData in QuantumDB")
    //        //get the date of last data import
    //        if let dateLastDatabaseImported = userDefaults.string(forKey: "dateLastDatabaseImported") {
    //            //copy new quantum from local SQLite DB to Master DB
    //            print("QuantumDB.swift: running function copyNewQuantamToMasterDB")
    //            self.copyNewQuantamToMasterDB {
    //                (status) in
    //                print("QuantumDB.swift: callback status of run copyNewQuantamToMasterDB call \(status)")
    //
    //                if status {
    //                    //delete new quanta from database
    //                    //DELETE THIS CODE: removed this added to copyNewQuantamToMasterDB function
    //                    //self.deleteNewQuantaFromLocalDB()
    //
    //                    //load new quanta from Master DB after date
    //
    //                    ///   will never be imported
    //                    print("QuantumDB.swift: calling getDataAfterDate")
    //
    //                    //THE PROBLEM IS IN THIS CALL
    //                    self.getDataAfterDate(dateLastDatabaseImported) {
    //                        (status) in
    //                            if status {
    //                                print("QuantumDB.swift: calling getDataUpdatedAfterDate")
    //                                self.getQuantumUpdatedAfterDateFromMasterDB(dateLastDatabaseImported) {
    //                                    (status) in
    //                                    //reset dateLastDatabaseImported user default with current date
    //                                    // add five seconds so the new notes are not imported
    //                                    if status {
    //                                        self.setDateLastImportUserDefault(5.0)
    //                                        callback(true)
    //                                    } else {
    //                                        callback(false)
    //                                    }
    //                                }
    //                            } else {
    //                                callback(status)
    //                            }
    //                    }
    //
    //                } else {
    //                    callback(false)
    //                }
    //            }
    //        } else {
    //            //if for some reason there is no date - reset dateLastDatabaseImported user
    //            //  default with current date
    //            self.setDateLastImportUserDefault(5.0)
    //            callback(false)
    //        }
    //    }
    
    //    //calls API and get all new quantum after last data import
    //    fileprivate func getDataAfterDate(_ lastLoadDate: String, callback:@escaping (Bool) -> ()) {
    //        print("QuantumDB.swift: calling called APIService.getQuantumCreatedAfterDate")
    //        service.getQuantumCreatedAfterDate(lastLoadDate) {
    //            (statusCode, response) in
    //
    //            //    print("data returned from getDataAfterDate fucntion in QuantumDB \(response["data"]! as! NSArray)")
    //            //check if api call was successful
    //            if statusCode == 200 {
    //                //convert data from API JSON data into NSArrays
    //                if let quantums = response["data"] as? NSArray {
    //                    print("QuantumDB.swift: quantumcount from \(quantums.count)")
    //                    if quantums.count > 0 {
    //                        //Load NSArray of Quantums into SQLite DB
    //                        print("QuantumDB.swift: calling called APIService.getQuantumCreatedAfterDate - response there was something")
    //
    //                        self.loadDataToDB(quantums)
    //                    }
    //                }
    //                callback(true)
    //            } else {
    //                callback(false)
    //            }
    //        }
    //    }
    //
    //    //calls API and gets all updatedquantum after last data import
    //    fileprivate func getQuantumUpdatedAfterDateFromMasterDB(_ lastLoadDate: String, callback:@escaping (Bool) -> ()) {
    //        print("QuantumDB.swift: calling called APIService.getDataUpdatedAfterDate")
    //        service.getQuantumUpdatedAfterDate(lastLoadDate) {
    //            (statusCode, response) in
    //
    //            //    print("data returned from getDataAfterDate fucntion in QuantumDB \(response["data"]! as! NSArray)")
    //            //check if api call was successful
    //            if statusCode == 200 {
    //                //convert data from API JSON data into NSArrays
    //                if let quantums = response["data"] as? NSArray {
    //                    if quantums.count > 0 {
    //                        //Load NSArray of Quantums into SQLite DB
    //                        print("QuantumDB.swift: calling called APIService.getQuantumUpdatedAfterDate - response there was something")
    //
    //                        self.loadUpdatedDataToLocalDB(quantums)
    //                    }
    //                }
    //                callback(true)
    //            } else {
    //                callback(false)
    //            }
    //        }
    //    }
    
    
    //    //Function takes any Quantum NSArray and updated data in SQLite3 DB
    //    //   example use - takes data from API call from master DB and updateds data in sqlite3 full text search virtual table
    //    //
    //    func loadUpdatedDataToLocalDB(_ data: NSArray){
    //        print("called loadUpdatedDataToLocalDB")
    //
    //        //parse data to quantum object then send to function that updates quantum
    //        for q in data {
    //            print("print q in loadUpdatedDataToDB function QuantumDB.swift \(q)")
    //            let quanta: Quantum
    //
    //            //cast or parse quanta into proper format
    //            if q is Quantum {
    //                quanta = q as! Quantum
    //            } else {
    //                quanta = Quantum(data: q as AnyObject)!
    //            }
    //
    //            quanta.dateUpdated = ""
    //
    //            self.updateQuantumInLocalDB(quanta)
    //        }
    //    }
    //
    //
    //    //copies new Quanta in local SQLite DB into Master DB
    //    //  new Quanta are marked new in field 'new'
    //    //  the new Quanta are delete from local SQLite DB after they are copied
    //       //    func copyNewQuantamToMasterDB(_ callback: (Bool) -> ()) {
    //        print("QuantumDB.swift: calling copyNewQuantaToMasterDB function")
    //        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    //        //var countQuantumAdded = 0
    //        //wrap it in a do catch for error catching
    //        do {
    //            //connect to the sqlite db
    //            let db = try Connection("\(path)/db.sqlite3")
    //
    //            //quantum full text search
    //            let quantum = VirtualTable("quantum")
    //            let id = Expression<String>("id")
    //            let note = Expression<String>("note")
    //            let dateCreated = Expression<String>("date")
    //            let newEntry = Expression<Bool>("new")
    //
    //            //perform keyword search
    //            let quantums = quantum.select(id, note, dateCreated).filter(newEntry == true)
    //
    //            //add query results to an array, so can get number of rows
    //            let quantumArray = Array(try db.prepare(quantums))
    //            print("quantum count before adding to masterdat \(quantumArray.count)")
    //
    //            //iterate through results
    //            for quanta in quantumArray {
    //                print("itereating through quant results for add new: print quanta")
    //                print(quanta)
    //
    //                //create Quantum Object and load it into a Quantum Array
    //                let loadQ = Quantum(id: quanta[id], userID: nil, note: quanta[note], dateCreated: quanta[dateCreated], dateUpdated: nil, new: false)
    //
    //                print("note that will be created raw data from sql prepare:\n \(quanta[note])")
    //
    //                //load service that posts quantum individually into Master DB
    //                service.createQuantum(loadQ) {
    //                    (code, response) in
    //                    print("api response \(response)")
    //                    print("api http code \(code)")
    //                    //checks for successful http status code
    //                    if code == 201 {
    //                        self.deleteQuantamFromLocalDB(loadQ)
    ////                        calls callback when all quantum are added
    ////                        countQuantumAdded += 1
    ////                        if countQuantumAdded == quantumArray.count {
    ////                            callback(true)
    ////                        }
    //                    }
    //                }
    //            }
    //            callback(true)
    //        } catch {
    //            callback(false)
    //            print("error")
    //        }
    //    }
    //
    //    //copies updated Quanta in local SQLite DB into Master DB
    //    //  updated Quanta are date_updated fields has a date
    //    func copyUpdatedQuantamToMasterDB(_ callback: (Bool) -> ()) {
    //        print("QuantumDB.swift: function run copyUpdatedQuantaToMasterDB function")
    //        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    //        //var countQuantumAdded = 0
    //        //wrap it in a do catch for error catching
    //        do {
    //            //connect to the sqlite db
    //            let db = try Connection("\(path)/db.sqlite3")
    //
    //            //quantum full text search
    //            let quantum = VirtualTable("quantum")
    //            let id = Expression<String>("id")
    //            let note = Expression<String>("note")
    //            let dateCreated = Expression<String>("date")
    //            let dateUpdated = Expression<String>("date_updated")
    //            //let newEntry = Expression<Bool>("new")
    //
    //            //perform keyword search
    //            //TODO = filter out new entries just for double check
    //            let quantums = quantum.select(id, note, dateCreated, dateUpdated).filter(dateUpdated != "")
    //
    //            //add query results to an array, so can get number of rows
    //            let quantumArray = Array(try db.prepare(quantums))
    //            print("quantum count before updating to masterdat \(quantumArray.count)")
    //
    //            //iterate through results
    //            for quanta in quantumArray {
    //                print("QuantumDB.swift: function copyUpdatedQuantamToMasterDB - itereating through quant results for updated: print quanta")
    //                print(quanta)
    //                print("\n")
    //                //create Quantum Object and load it into a Quantum Array
    //                let loadQ = Quantum(id: quanta[id], userID: nil, note: quanta[note], dateCreated: quanta[dateCreated], dateUpdated: quanta[dateUpdated], new: false)
    //
    //                print("QuantumDB.swift: function copyUpdatedQuantamToMasterDB - note that will be updated raw data from sql prepare:\n \(quanta[note])")
    //
    //                //load service that posts quantum individually into Master DB
    //                service.updateQuantum(loadQ) {
    //                    (code, response) in
    //                    print("QuantumDB.swift: api response \(response)")
    //                    print("QuantumDB.swift: api http code \(code)")
    //                    //checks for successful http status code
    //                    if code == 200 {
    //                        //update quantum in local db - set dateUpdated to nothing
    //                        loadQ.dateUpdated = ""
    //                        self.updateQuantumInLocalDB(loadQ)
    //                    }
    //                }
    //            }
    //            callback(true)
    //        } catch {
    //            print("QuantumDB.swift: function copyUpdatedQuantamToMasterDB  - error")
    //            callback(false)
    //        }
    //    }
    //
    //    //deletes new Quanta that have new field marked true
    //    func deleteNewQuantaFromLocalDB() {
    //        print("QuantumDB.swift: run deleteNewQuantaFromLocalDB function")
    //
    //        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    //
    //        //wrap it in a do catch for error catching
    //        do {
    //            //connect to the sqlite db
    //            let db = try Connection("\(path)/db.sqlite3")
    //            
    //            //quantum full text search
    //            let quantum = VirtualTable("quantum")
    //            let newEntry = Expression<Bool>("new")
    //            
    //            //perform keyword search
    //            let quantums = quantum.filter(newEntry == true)
    //            //iterate through results
    //            try db.run(quantums.delete())
    //        } catch {
    //            print("error")
    //        }
    //    }
    //

}
