//
//  APIService.swift
//  fatmind
//
//  Created by Rix on 12/28/15.
//  Copyright © 2015 bitcore. All rights reserved.
//

import Foundation

class APIService {
    //static api key for app
    let apiKey = "aD7WrqSxV8ur7C59Ig6gf72O5El0mz04"
    //user api authentication token
    let apiToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyIkX18iOnsic3RyaWN0TW9kZSI6dHJ1ZSwic2VsZWN0ZWQiOnsicXVhbnRhIjowfSwiZ2V0dGVycyI6e30sIndhc1BvcHVsYXRlZCI6ZmFsc2UsImFjdGl2ZVBhdGhzIjp7InBhdGhzIjp7ImVtYWlsIjoiaW5pdCIsInBhc3N3b3JkIjoiaW5pdCIsInVzZXJuYW1lIjoiaW5pdCIsImNyZWF0ZWRPbiI6ImluaXQiLCJfX3YiOiJpbml0IiwiX2lkIjoiaW5pdCJ9LCJzdGF0ZXMiOnsiaWdub3JlIjp7fSwiZGVmYXVsdCI6e30sImluaXQiOnsiX192Ijp0cnVlLCJjcmVhdGVkT24iOnRydWUsImVtYWlsIjp0cnVlLCJwYXNzd29yZCI6dHJ1ZSwidXNlcm5hbWUiOnRydWUsIl9pZCI6dHJ1ZX0sIm1vZGlmeSI6e30sInJlcXVpcmUiOnt9fSwic3RhdGVOYW1lcyI6WyJyZXF1aXJlIiwibW9kaWZ5IiwiaW5pdCIsImRlZmF1bHQiLCJpZ25vcmUiXX19LCJpc05ldyI6ZmFsc2UsIl9tYXhMaXN0ZW5lcnMiOjAsIl9kb2MiOnsiY3JlYXRlZE9uIjoiMjAxNS0xMC0yN1QyMDowOTowMy4wODFaIiwiX192IjowLCJlbWFpbCI6InJpeGVtcGlyZUBnbWFpbC5jb20iLCJwYXNzd29yZCI6IiQyYSQxMCR1UHJ3eW9ZbnFaNVZuRlRyRllLbWJPaTZxWFZmMjJEejdJd2JkbU9ET29oMnBGbzZVU0tCSyIsInVzZXJuYW1lIjoiZHJvcGFjaWQiLCJfaWQiOiI1NjJmZDlkZjAxMjFjZGU4MjE0YmY1YTEifSwiX3ByZXMiOnsic2F2ZSI6W251bGwsbnVsbCxudWxsLG51bGxdfSwiX3Bvc3RzIjp7InNhdmUiOltdfSwiaWF0IjoxNTAyOTc3NDgwLCJleHAiOjE1MDMwMjA2ODB9.Km8ThoaGORyHVIapRBR3gleU54gu3ppzPc67OBiUCIc"
    //base url for api
    //let apiURL = "http://localhost:3000"

    let apiURL = "http://192.168.25.128:3000"
    
    init(){}
    
    // MARK: - Quantum API Calls
    
    //GET is api alive
    func getIsServiceAlive(_ callback: @escaping (Bool) -> ()) {
        print("APIService.swift: getIsServiceAlive")

        let url = "\(apiURL)/api/areyoualive"
        
        get(withURL: url, withTimeout: 3){
            (statusCode, response) in
            print("status code \(statusCode)")
            
            if statusCode == 200 {
                callback(true)
            } else {
                callback(false)
            }
        }
    }
    
    //GET a list of all quanta
    func getQuantamAll(_ callback:@escaping (Int, NSDictionary) -> ()) {
        print("APIService.swift: getQuantamAll")
        
        let url = "\(apiURL)/api/quantum/all"
        
        get(withURL: url, withTimeout: 30, withCallback: callback)
    }
    
    //GET WITH PARAMS a list of quanta created after date
    func getSyncFromServerByDate(withDateOfLastUpdate date:String, callback:@escaping (Int, NSDictionary) -> ()) {
        let url = "\(apiURL)/api/quantum/sync"
        let postParam  = "?datelastupdate=\(date)"
        
        print("APIService.swift: last date updated in getQuantumCreatedAFterDate in API server \(date)")
        //postWithParams(url, postParam:postParam, callback: callback)
        self.getWithParams(url, params: postParam, callback: callback)
    }
    
    
    //GET a list of all quanta
    func getServerCounterLastSync(_ callback:@escaping (Int, NSDictionary) -> ()) {
        print("APIService.swift: getServerCounterLastSync")
        
        let url = "\(apiURL)/api/countersync"
        
        get(withURL: url, withTimeout: 30, withCallback: callback)
    }

    
    //GET WITH PARAMS a list of quanta created after date
    func getSyncFromServer(byServerSyncCounter counter:Int, callback:@escaping (Int, NSDictionary) -> ()) {
        let url = "\(apiURL)/api/quantum/sync"
        let postParam  = "?counter=\(counter)"
        
        print("APIService.swift: getSyncFromServer  \(counter)")
        //postWithParams(url, postParam:postParam, callback: callback)
        self.getWithParams(url, params: postParam, callback: callback)
    }

    //POST Sync changes from client to server
    func postSyncToServer(withQuantumList qList: [Quantum], callback:@escaping (Int, NSDictionary) -> ()) {
        let url = "\(apiURL)/api/quantum/sync"
        if let postJSON = Quantum.quantumToJSON(quantumList: qList) {
            postWithJSON(url, postData: postJSON as Data, callback: callback)
        } else {
            callback(0, ["0": "error converting quantum body to json"])
        }
    }
    
//  /// NOT USED
    //
//    //GET WITH PARAMS a list of quanta created after date
//    func getQuantumCreatedAfterDate(_ dateLastUpdate:String, callback:@escaping (Int, NSDictionary) -> ()) {
//        let url = "\(apiURL)/api/quantum/bydate"
//        let postParam  = "?datelastupdate=\(dateLastUpdate)"
//        
//        print("APIService.swift: last date updated in getQuantumCreatedAFterDate in API server \(dateLastUpdate)")
//        //postWithParams(url, postParam:postParam, callback: callback)
//        self.getWithParams(url, params: postParam, callback: callback)
//    }
//
//    //GET WITH PARAMS a list of quanta created after date
//    func getQuantumUpdatedAfterDate(_ dateLastUpdate:String, callback:@escaping (Int, NSDictionary) -> ()) {
//        let url = "\(apiURL)/api/quantum/bydateupdated"
//        let postParam  = "?datelastupdate=\(dateLastUpdate)"
//        
//        print("APIService.swift: ast date updated in getQuantumUpdatedAfterDate in API server \(dateLastUpdate)")
//        //postWithParams(url, postParam:postParam, callback: callback)
//        self.getWithParams(url, params: postParam, callback: callback)
//    }
//    
//    //POST - create a quantum
//    func createQuantum(_ q: Quantum, callback:@escaping (Int, NSDictionary) -> ()) {
//        let url = "\(apiURL)/api/quantum/"
//        //let postParam:NSString = "note=\(q.note!)"
//        if let postJSON = q.noteToJSON() {
//            postWithJSON(url, postData: postJSON as Data, callback: callback)
//        } else {
//            callback(0, ["0": "error converting quantum body to json"])
//        }
//    }
//    
//    
//    
//    //PUT - update a quantum
//    func updateQuantum(_ q: Quantum, callback:@escaping (Int, NSDictionary) -> ()) {
//        let url = "\(apiURL)/api/quantum/\(q.id!)"
//        //let postParam:NSString = "note=\(q.note!)"
//        if let postJSON = q.noteToJSON() {
//            putWithJSON(url, postData: postJSON as Data, callback: callback)
//        } else {
//            callback(0, ["0": "error converting quantum body to json"])
//        }
//    }
//
//    
    
    
    
    // MARK: - Generic API Calls
    
    //GET API Call
    func get(withURL url:String, withTimeout time:Int, withCallback callback:@escaping (Int, NSDictionary) -> ()) {
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.url = URL(string: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiToken, forHTTPHeaderField: "x-access-token")
        request.timeoutInterval = TimeInterval(time)
        //execute the request
        let task = URLSession.shared.dataTask(with: request as URLRequest) {
            data, response, error in
            
            print("APIService.swift: get call  api error \(String(describing: error))")
            print("APIService.swift: get call api data \(String(describing: data))")

            //Check for connectivity
            if let e = error {
                callback(0, ["data" : e.localizedDescription ])
            } else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode
                print("APIService: get request statuscode : \(statusCode)")
                
                //parse JSON to NSDictionary
                do {
                    if let jsonResult = try (JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)) as? NSDictionary {
                        callback(statusCode, jsonResult)
                    } else {
                        callback(statusCode, ["data" : "nil returned while parsing JSON" ])
                    }
                } catch {
                    callback(0, ["data" : "error parsing to JSON" ])
                }
           }
        }
        
        task.resume()
    }
    
    //GET with Params API Call
    func getWithParams(_ url: String, params: String, callback:@escaping (Int, NSDictionary) -> ()) {
        
        //encode the parameter string
        let expectedCharSet = CharacterSet.urlQueryAllowed
        let encodedParams = params.addingPercentEncoding(withAllowedCharacters: expectedCharSet)!
        //combine url with parameters
        let fullURL = url + encodedParams
        print("full url from get with params \(fullURL)")
        //start building the http request
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.url = URL(string: fullURL)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiToken, forHTTPHeaderField: "x-access-token")
        
        let url2 = URL(string: fullURL)
        
        var request2 = URLRequest(url: url2!)
        request2.httpMethod = "GET"
        request2.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request2.addValue(apiToken, forHTTPHeaderField: "x-access-token")
        
        //execute the request
        let task = URLSession.shared.dataTask(with: request as URLRequest) {
            data, response, error in
            
            print("APIService.swift: get call  api error \(String(describing: error))")
            print("APIService.swift: get call api data \(String(describing: data))")
            
            
            //Check for connectivity
            if let e = error {
                callback(0, ["data" : e.localizedDescription ])
            } else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode
                print("APIService: getWithParams request statuscode : \(statusCode)")
                //parse JSON to NSDictionary
                do {
                    if let jsonResult = try (JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)) as? NSDictionary {
                        callback(statusCode, jsonResult)
                    } else {
                        callback(statusCode, ["data" : "nil returned while parsing JSON" ])
                    }
                } catch {
                    callback(0, ["data" : "error parsing to JSON" ])
                }
            }
        }
        
        task.resume()
    }

    
    //Post With PARAMS API Call using Form Post
    func postWithParams(_ url: String, postParam: String, callback: @escaping (Int, NSDictionary) -> ()) {
        //encode params
        let postData:Data = postParam.data(using: String.Encoding.ascii)!
        let postLength:NSString = String( postData.count) as NSString
        print("post params data \(postData)")
        //create http request
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.url = URL(string: url)
        request.httpMethod = "POST"
        request.httpBody = postData
        request.setValue(postLength as String, forHTTPHeaderField: "Content-Length")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiToken, forHTTPHeaderField: "x-access-token")
        //execute the request
        let task = URLSession.shared.dataTask(with: request as URLRequest) {
            data, response, error in
            print(error!)
            //check for connection error
            if let e = error {
                callback(0, ["data" : e.localizedDescription ])
            } else {

                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode
                //parse JSON to NSDictionary
                do {
                    if let jsonResult = try (JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)) as? NSDictionary {
                        callback(statusCode, jsonResult)
                    } else {
                        callback(statusCode, ["data" : "nil returned while parsing JSON" ])
                    }
                } catch {
                    callback(0, ["data" : "error parsing to JSON" ])
                }
            }
        }
        
        task.resume()
    }

    //POST API Call with JSON httpBody
    func postWithJSON(_ url: String, postData: Data, callback: @escaping (Int, NSDictionary) -> ()) {
        //prepare post data for http body
        var postLength = "0"
        if let pLen = NSString(data: postData, encoding: String.Encoding.utf8.rawValue)?.length {
            print("json data converted to string to see id: \n \(NSString(data: postData, encoding: String.Encoding.utf8.rawValue)!)")
            postLength = String(pLen)
        }
        
        //start building the http request object
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.url = URL(string: url)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = postData
        request.setValue(postLength, forHTTPHeaderField: "Content-Length")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiToken, forHTTPHeaderField: "x-access-token")
        //execute the request 
        let task = URLSession.shared.dataTask(with: request as URLRequest) {
            data, response, error in
            //check for connection error
            
            if let e = error {
                callback(0, ["data" : e.localizedDescription ])
            } else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode
                //parse JSON to NSDictionary
                do {
                    if let jsonResult = (try JSONSerialization.jsonObject(with: data!,options: JSONSerialization.ReadingOptions.mutableContainers)) as? NSDictionary {
                        callback(statusCode, jsonResult)
                    } else {
                        callback(statusCode, ["data" : "nil returned while parsing JSON" ])
                    }
                } catch {
                    callback(0, ["data" : "error parsing to JSON" ])
                }
            }
        }

        
        task.resume()
    }
    
    //PUT API Call with JSON httpBody
    func putWithJSON(_ url: String, postData: Data, callback: @escaping (Int, NSDictionary) -> ()) {
        //prepare post data for http body
        print("putWithJSON Called")
        
        var postLength = "0"
        if let pLen = NSString(data: postData, encoding: String.Encoding.utf8.rawValue)?.length {
            print("json data converted to string to see id: \n \(NSString(data: postData, encoding: String.Encoding.utf8.rawValue)!)")
            postLength = String(pLen)
        }
        
        //start building the http request object
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.url = URL(string: url)
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "PUT"
        request.httpBody = postData
        request.setValue(postLength, forHTTPHeaderField: "Content-Length")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiToken, forHTTPHeaderField: "x-access-token")
        //execute the request
        let task = URLSession.shared.dataTask(with: request as URLRequest) {
            data, response, error in
            //check for connection error
            
            if let e = error {
                callback(0, ["data" : e.localizedDescription ])
            } else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode
                //parse JSON to NSDictionary
                do {
                    if let jsonResult = (try JSONSerialization.jsonObject(with: data!,options: JSONSerialization.ReadingOptions.mutableContainers)) as? NSDictionary {
                        callback(statusCode, jsonResult)
                    } else {
                        callback(statusCode, ["data" : "nil returned while parsing JSON" ])
                    }
                } catch {
                    callback(0, ["data" : "error parsing to JSON" ])
                }
            }
        }
        
        task.resume()
    }

}
