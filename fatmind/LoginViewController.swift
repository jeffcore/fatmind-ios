//
//  LoginViewController.swift
//  fatmind
//
//  Created by jeffrix on 8/10/20.
//  Copyright © 2020 bitcore. All rights reserved.
//


import UIKit

class LoginViewController: UIViewController {
    
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var loginSubmit: UIButton!
    
    var window: UIWindow?
    
    let user = User()
    let quantumDB = QuantumDB()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //start animating the indicator
        // loadingIndicator.startAnimating()
        
    }
    
    @IBAction func loginButtonClicked(_ sender: UIButton) {
        
        if email.text != "" && password.text != "" {
            user.login (withEmail: email.text!, withPassword: password.text!, {
                (status) in
                print("login status code \(status)")
                    //check if the initial database was loaded from master
                if status {
                    if self.quantumDB.isInitialDataLoaded() {
                        print("appdelegate isinitaldataloaded is true")
                        // utility function to see all quantums in db
                        // quantumDB.getAllQuantum();
                        // quick sync no need for loading screen
                        self.quantumDB.mainSync() {
                            (status) in
                            print(status)
                            DispatchQueue.main.async {
                                self.dismiss(animated: true, completion: nil)
                            }
                        }
                        
                    } else {
                        // entire sync - this can take a while so there is a loading screen
                        DispatchQueue.main.async {
                            print("data never imported move to seque")
                            self.performSegue(withIdentifier: "LoginToLoadingData", sender: self)
                        }
                    }
                }
            })
        }
      
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        // self.navigationController?.popViewController(animated: true)
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
    }
}

