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
    
    public func openDB() -> Bool {
        
        if sqlite3_open(dataFilePath(), &db) == SQLITE_OK {
            print("connected to db")
            return true
        } else {
            print("Unable to open database. Verify that you created the directory described ")
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
            "note TEXT, date_created TEXT, date_updated TEXT" +
            "updated INT, deleted INT, new INT);"
    
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
 
    
    //runs loading of Master DB into local SQLite DB for the first time
    // the code in this function only calls the API and loads the data into an NSArray
    // then it sends the Quantum NSArray to the loadDataToDB() function
    public func runInitialDataLoad(_ callback: @escaping (Bool) -> ()) {
        print("QuantumDB.swift: run initialDataLoad Function in  QuantumDB.swift")
        //import initial data to sqlite3 full text search virtual table
        service.getQuantamAll{
            (statusCode, response) in
            //print(response["data"]! as! NSArray)
            if statusCode == 200 {
                if let quantums = response["data"] as? NSArray {
                    self.insertNewDataToDB(quantums)
                    print("json load")
                    //print(quantums)
                }
                print("status code erorr \(statusCode)")
                //update user defaults
                self.userDefaults.set(true, forKey: "databaseImported")
                self.setDateLastImportUserDefault(5.0)

                callback(true)
            } else {
                print("status code erorr \(statusCode)")
                callback(false)
            }
        }
    }
    
    
    public func getChanges() {
        var quantumList = [Quantum]()
        
        var queryStatement: OpaquePointer? = nil
        let queryStatementString = "SELECT id, note, new, updated, deleted FROM quantum" +
                " WHERE (new = 1 OR updated = 1 OR deleted = 1);"
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            
            var id = ""
            var note = ""
            var new : Int32 = 0
            var updated : Int32 = 0
            var deleted : Int32 = 0
            
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
                
                new = sqlite3_column_int(queryStatement, 2)
                updated = sqlite3_column_int(queryStatement, 3)
                deleted = sqlite3_column_int(queryStatement, 4)
                
                let loadQ = Quantum(id: id, userID: nil, note: note, dateCreated: nil, dateUpdated: nil,
                                    new: new.toBool(), updated: updated.toBool(), deleted: deleted.toBool())
                
                quantumList.append(loadQ)
                
                print("Query Result:")
                print("\(id) | \(note) | \(new) | \(updated) | \(deleted)")
                
            }
        } else {
            print("SELECT statement could not be prepared")
        }
        
        sqlite3_finalize(queryStatement)
        
        
        service.sendChangesToMasterDB(quantumList: quantumList) {
            (statusCode, response) in
            
            print(response["message"])
            print("update file sent to master db")
        }
        
    }

    
    //loads quantum changes from API service
    public func syncNewDataFromMaster(_ callback: @escaping (Bool) -> ()) {
        print("QuantumDB.swift: running function runLoadNewData in QuantumDB")
        //get the date of last data import
        if let dateLastDatabaseImported = userDefaults.string(forKey: "dateLastDatabaseImported") {
            //copy new quantum from local SQLite DB to Master DB
            print("QuantumDB.swift: running function copyNewQuantamToMasterDB")
            service.getSyncFromServer(withDateOfLastUpdate: dateLastDatabaseImported) {
                (statusCode, response) in

                //    print("data returned from getDataAfterDate fucntion in QuantumDB \(response["data"]! as! NSArray)")
                //check if api call was successful
                if statusCode == 200 {
                    //convert data from API JSON data into NSArrays
                    if let quantums = response["data"] as? NSArray {
                        print("QuantumDB.swift: quantumcount from \(quantums.count)")
                        if quantums.count > 0 {
                            //Load NSArray of Quantums into SQLite DB
                            print("QuantumDB.swift: calling called APIService.getQuantumCreatedAfterDate - response there was something")
                            print(quantums)
                            self.syncInsertUpdateDataToDB(withNSArray: quantums)
                        }
                    }
                    callback(true)
                } else {
                    callback(false)
                }
            }
        } else {
            //if for some reason there is no date - reset dateLastDatabaseImported user
            //  default with current date
            print("set new date")
            self.setDateLastImportUserDefault(5.0)
            callback(false)
        }
    }
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

    // MARK: - SQLite DB Functions
    
   

    
    //Function takes any Quantum NSArray and inserts it into the SQLite3 DB
    //   example use - takes data from API call and loads into sqlite3 full text search virtual table
    //  this also used to load one quantum to the local db
    public func insertNewDataToDB(_ data: NSArray){
        print("called loadDataToDB")
        
        var insertStatement: OpaquePointer? = nil
        
        let insertStatementString = "INSERT INTO quantum (id, note, date_created, new)" +
                                    "VALUES (?, ?, ?, ?);"
        
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
                sqlite3_bind_int(insertStatement, 4, Int32(quantum.newToInt))
                
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
                quantum.updated = false
                self.updateQuantumInLocalDB(withQuantum: quantum)
            } else {
                self.insertQuantumToLocalDB(withQuantum: quantum)
            }
            
        }
        
    }
    

    
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
//    //  TODO: 1. delete individual quantum after they are added
//    func copyNewQuantamToMasterDB(_ callback: (Bool) -> ()) {
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
//    //deletes new Quanta that have new field marked true
//    func deleteQuantamFromLocalDB(_ q: Quantum) {
//        print("QuantumDB.swift: run deleteQuantaByIDFromLocalDB function")
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
//            let id = Expression<String>("id")
//            
//            //perform keyword search
//            let quantums = quantum.filter(id == q.id!)
//            //iterate through results
//            try db.run(quantums.delete())
//        } catch {
//            print("error")
//        }
//    }
//
    //full text search for quanta
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
                
//                if let queryResult2 = sqlite3_column_text(queryStatement, 2) {
//                    dateCreated = String(cString: queryResult2)
//                } else {
//                    dateCreated = ""
//                }
                
                let loadQ = Quantum(id: id, userID: nil, note: note, dateCreated: dateCreated, dateUpdated: nil, new: false, updated: false, deleted: false)
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

    //inserts one quantum into local Sqlite DB
    public func insertQuantumToLocalDB(withQuantum quantum : Quantum){
        print("called insertOneQuantumToDB")
        
        var insertStatement: OpaquePointer? = nil
        
        let insertStatementString = "INSERT INTO quantum (id, note, date_created, new)" +
        "VALUES (?, ?, ?, ?);"
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            
            //add all data to full text virtual table
            
            sqlite3_bind_text(insertStatement, 1, (quantum.id! as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (quantum.note! as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, (quantum.dateCreated! as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 4, Int32(quantum.newToInt))
            
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

    //Updates Quantum in local SQLite DB
    func updateQuantumInLocalDB(withQuantum q: Quantum) {
        
        var updateStatement: OpaquePointer? = nil
        let updateStatementString = "UPDATE quantum SET note = ?, updated = ?," +
            " WHERE id = ?;"
        
        if sqlite3_prepare_v2(db, updateStatementString, -1, &updateStatement, nil) == SQLITE_OK {
          
            sqlite3_bind_text(updateStatement, 1, (q.note! as NSString).utf8String, -1, nil)
            sqlite3_bind_int(updateStatement, 2, Int32(q.updatedToInt))
            sqlite3_bind_text(updateStatement, 3, (q.id! as NSString).utf8String, -1, nil)
            
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

    //sets the UserDefault for the Date the last time the local SQLite DB was updated from the Master DB
    fileprivate func setDateLastImportUserDefault(_ addSeconds: Double)  {
        //format date for API call to get new quantums since last visit
        let dateNow = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z" //format style. Browse online to get a format that fits your needs.
        
        //dateFormatter.timeZone = NSTimeZone(abbreviation: "UTC");
        //convert date to string
        let dateNowString = dateFormatter.string(from: dateNow.addingTimeInterval(addSeconds))
        //set the user default date
        userDefaults.set(dateNowString, forKey: "dateLastDatabaseImported")
    }
    
    //check if initial (first time import) of data has happened
    //  stored in databaseImported user default
    open func isInitialDataLoaded() -> Bool {
        let isInitialLoad = userDefaults.bool(forKey: "databaseImported")
        if isInitialLoad {
            print("database WAS imported")
            return true
        } else {
            print("database not imported")
            return false
        }
    }
    
   
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    //   TO BE DELETED
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
    //                    //TODO: big flaw - if new import works, and updated import fails - date will change, so updates
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
    


}

extension Int32 {
    
    func toBool () -> Bool {
        
        switch self {
            case 0:
                return false
            case 1:
                return true
            default:
                return true
        }
    }
}
