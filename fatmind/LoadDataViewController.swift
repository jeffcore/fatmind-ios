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
        //run the initial data import
        if quantumDB.openDB() {
            if quantumDB.createDB() {
                print("DB CREATED")
                
                self.quantumDB.runInitialDataLoad {
                    (status) in
                    if status {
                        print("data successfully imported")
                        
                    } else {
                        print("problem importing database")
                    }
                    DispatchQueue.main.async{
                        self.performSegue(withIdentifier: "SegueToMainVC", sender: self)
                    }
                }
            }
        }
    }

}
