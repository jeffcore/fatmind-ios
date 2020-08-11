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
    

    
    override func viewDidLoad() {
        super.viewDidLoad()
        //start animating the indicator
        // loadingIndicator.startAnimating()
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

