//
//  Quantum.swift
//  fatmind
//
//  Created by Rix on 4/16/16.
//  Copyright © 2016 bitcore. All rights reserved.
//

import Foundation

class Quantum {
    var id: String?
    var userID: String?
    var note: String?
    var dateCreated: String?
    var dateUpdated: String?
    var deleted: Bool = false
    var deletedToInt: Int {
        return self.deleted ? 1 : 0
    }
    
    init(id: String, userID: String?, note: String?, dateCreated: String?, dateUpdated: String?, deleted: Bool) {
        self.id = id
        self.userID = userID
        self.note = note
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
        self.deleted = deleted
    }
    
    //initialize with an AnyObject - this is used with the data returned from the api calls
    //  the data format is an AnyObject[string, anyobject]
    init?(data: AnyObject){
        if let q = data as? NSDictionary
        {
            if let q_id = q["guid"] as? String {
                self.id = q_id
            } else {
                print("anyobject id conversion did not work")

                return nil
            }
            
            if let q_userIDDic = q["userID"] as? NSDictionary {
                if let q_userID = q_userIDDic["_id"] as? String {
                    self.userID = q_userID
                } else {
                    print("usernid id conversion did not work")
                    return nil
                }
            } else {
                print("usernid id conversion did not work")
                return nil
            }
            
            if let q_note = q["note"] as? String {
                self.note = q_note
            } else {
                self.note = ""
            }
            
            if let q_dateCreated = q["dateCreated"] as? String {
                self.dateCreated = q_dateCreated
            }
            
            if let q_dateUpdated = q["dateUpdated"] as? String {
                self.dateUpdated = q_dateUpdated
            } else {
                self.dateUpdated = ""
            }
        } else {
            print("anyobject conversion did not work")
            return nil
        }
    }
    
    //convert note property to  JSON nsdata object
    func noteToJSON () -> Data? {
        var noteNSData : Data?
        
        let noteJSON = ["note": self.note!]
        
        do {
            noteNSData = try JSONSerialization.data(withJSONObject: noteJSON, options: [] )
        } catch {
            noteNSData = nil
        }
        print("contents of noteToJSON \(noteNSData)")
        return noteNSData
    }
    
        
    static func quantumToJSON(quantumList qList: [Quantum]) -> Data? {
        
        var quantumDictionary = [[String: String]]()
        
        var quantumJSON : Data?
        
        var quantumData: Dictionary<String, String>
        
        for q in qList {
            quantumData = ["id": q.id!, "note": q.note!, "deleted": String(q.deletedToInt), "dateUpdated": q.dateUpdated! ]

            quantumDictionary.append(quantumData)            
        }
        
        do {
            quantumJSON = try JSONSerialization.data(withJSONObject: quantumDictionary, options: [])
        } catch {
            quantumJSON = nil
        }
        
        print(String(data: quantumJSON!, encoding: String.Encoding.utf8))
        return quantumJSON
    }
    
}
