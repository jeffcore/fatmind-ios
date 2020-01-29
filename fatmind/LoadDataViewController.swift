//
//  LoadDataViewController.swift
//  fatmind
//
//  Created by Rix on 4/30/16.
//  Copyright © 2016 bitcore. All rights reserved.
//

import UIKit

class LoadDataViewController: UIViewController {
    
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    let quantumDB = QuantumDB()
    let service = APIService()
    var window: UIWindow?
    
    @IBOutlet weak var lblActivity: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //start animating the indicator
        loadingIndicator.startAnimating()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //db not imported so run the initial data import
        if quantumDB.openDB() {
            service.getIsServiceAlive {
                (status) in
                if status {
                    // self.lblActivity.text = "service available"
                    print("AppDelegate.swift: quantumDB.syncToServer ")

                    self.quantumDB.syncFromServer {
                    (status) in
                        print("AppDelegate.swift: quantumDB.syncFromServer return status - \(status)")
                        if status {
                            self.quantumDB.syncToServer {
                                (status) in
                                if status {
                                    print("AppDelegate.swift: status of run quantumDB.syncToServer  call - \(status)")
                                }
                                DispatchQueue.main.async{
                                    self.performSegue(withIdentifier: "SegueToMainVC", sender: self)
                                }
                            }
                        } else {
                            DispatchQueue.main.async{
                                self.performSegue(withIdentifier: "SegueToMainVC", sender: self)
                            
                            }
                        }
                    }
                } else {
                    self.lblActivity.text = "service unavailable"
                    DispatchQueue.main.async{
                        self.performSegue(withIdentifier: "SegueToMainVC", sender: self)
                    }
                    print("no service")
                }
            }
        }
    }
}
