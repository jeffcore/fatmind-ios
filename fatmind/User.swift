//
//  User.swift
//  fatmind
//
//  Created by jeffrix on 11/11/20.
//  Copyright © 2020 bitcore. All rights reserved.
//

import Foundation


class User {
    var service = APIService()
    var apiToken = ""
    
    init(){        
        apiToken = UserDefaults.standard.string(forKey: "token") ?? ""
    }

    
    func needLogin() -> Bool {
        if apiToken == "" {
            return true
        } else {
            return false
        }
    }
    
    func login(withEmail email:String, withPassword password:String, _ callback: @escaping (Bool) -> ()) {
        
        service.loginUser (withEmail: email, withPassword: password) {
            (statusCode, data) in
            print("login status code \(statusCode)")
            if statusCode != 401 && statusCode != 0 {
                print(data["token"]!)
                UserDefaults.standard.set(data["token"]!, forKey: "token")
                callback(true)
            } else {
                callback(false)
            }
        }
        
    }
    
}
