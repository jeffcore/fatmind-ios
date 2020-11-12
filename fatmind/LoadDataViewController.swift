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
    func getTopMostViewController() -> UIViewController? {
        var topMostViewController = UIApplication.shared.keyWindow?.rootViewController

        while let presentedViewController = topMostViewController?.presentedViewController {
            topMostViewController = presentedViewController
        }

        return topMostViewController
    }
    override func viewDidAppear(_ animated: Bool) {
        //db not imported so run the initial data import
        if quantumDB.openDB() {
            
            print("AppDelegate.swift: quantumDB.syncToServer ")

            self.quantumDB.mainSync() {
                (status) in
                print(status)
                print("got here inital sync before segue")
               
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                    self.presentingViewController?.presentingViewController?.dismiss(animated: true, completion: nil)

                    
                }
            }
        }
        
    }
}
