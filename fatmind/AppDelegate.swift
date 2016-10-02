//
//  AppDelegate.swift
//  fatmind
//
//  Created by Rix on 11/18/15.
//  Copyright © 2015 bitcore. All rights reserved.
//

import UIKit
//import SQLite

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch. 
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        print("did become active")
        print("AppDelegate.swift")
        let service = APIService()
        let quantumDB = QuantumDB()
        
        //check if the initial database was loaded from master
        if quantumDB.isInitialDataLoaded() {
            if quantumDB.openDB(){
                service.getIsServiceAlive {
                    (status) in
                    if status {
                        print("AppDelegate.swift: service is alive")
                        print("AppDelegate.swift: running  quantumDB.runLoadNewData")
                       quantumDB.syncNewDataFromMaster {
                            (status) in
                            print("AppDelegate.swift: quantumDB.runLoadNewData return status - \(status)")
                            if status {
                                print("AppDelegate.swift: quantumDB.copyUpdatedQuantamToMasterDB ")

    //                            quantumDB.copyUpdatedQuantamToMasterDB {
    //                                (status) in
    //                                if status {
    //                                    print("AppDelegate.swift: status of run quantumDB.copyUpdatedQuantamToMasterDB  call - \(status)")
    //                                }
    //                            }
                            }
                        }
                       
                    }
                }
            }
        } else {
            print("data never imported move to seque")
            let storyboard:UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let vc:LoadDataViewController = storyboard.instantiateViewController(withIdentifier: "LoadDataViewController") as! LoadDataViewController
            self.window?.rootViewController = vc
            self.window?.makeKeyAndVisible()
        }
//        
       // self.preloadData()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
    }
   
    //preloads all the data 
    //  First App Load - the entire master DB is loaded into SQLite DB
    //  Second ... n App Load - it loads new quantums from master DB into SQLite DB
    func preloadData() {
//        service.getIsAlive {
//            (isAlive) in
//            
//            if isAlive {
//                print("api is alive")
//                
//                if self.quantumDB.isInitialDataLoaded() {
//                   
//                    self.quantumDB.runLoadNewData {
//                        (status) in
//                        if status {
//                            print("status of run loadnewdata call \(status)")
//                        }
//                        
//                    }
//                    
//                } else {
//                    
//                    dispatch_async(dispatch_get_main_queue()){
//
//                        let storyboard:UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
//                        let vc:LoadDataViewController = storyboard.instantiateViewControllerWithIdentifier("LoadDataViewController") as! LoadDataViewController
//                        
//                        self.window?.rootViewController?.presentViewController(vc, animated: true, completion: nil)
//                    }
//                    
//                }
//            }
//        }
    }
    
}
