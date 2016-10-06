//
//  ViewController.swift
//  fatmind
//
//  Created by Rix on 11/18/15.
//  Copyright © 2015 bitcore. All rights reserved.
//

import UIKit
import Foundation

enum QuantumState {
    case editing, adding
}


class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate {

    @IBOutlet weak var quantumTextView: UITextView!
    @IBOutlet weak var quantumListTableView: UITableView!
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    
    let basicCellIdentifier = "BasicCell"
    var returnedPressed = 0
    var quantumIndex = 0
    var quantumState = QuantumState.adding
   
    var quantumList = [Quantum]()
    let service = APIService()
    let quantumDB = QuantumDB()
    
// MARK: - ViewController Functions

    override func viewDidLoad() {
        super.viewDidLoad()
       
        //self.hideKeyboardWhenTappedAround()
        self.quantumTextView.delegate = self
        
        //add left swipe to UITextView to delete text
        let tapTerm:UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(clearUITextView))
        tapTerm.direction = .left
        self.quantumTextView.addGestureRecognizer(tapTerm)
        
        //add auto focus to UITextView
        self.quantumTextView.becomeFirstResponder()
        
        //set up Table List View
        self.quantumListTableView.register(UITableViewCell.self, forCellReuseIdentifier: basicCellIdentifier)
        self.quantumListTableView.delegate = self
        self.quantumListTableView.dataSource = self
        
        //open and connect to db
        if quantumDB.openDB() {
            print("database opened")
        }
                       
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        //set the scroll to start at the top of the content
        self.quantumTextView.setContentOffset(CGPoint.zero, animated: false)
    }
    
    //hide the status bar
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    //capture when return is pressed in textview and execute the search
    //two states 
    //1. cleared textbox 
    //     after second return save
    //2. opened existing quantum
    //     any return saves - you might not always hit return when you edit
    //       -todo any keypress saves 
    //       -exiting current quantum - clear or select a new one
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            
            print("return but pressed")
            
            switch quantumState {
                case .adding:
                    print("in adding")
                    self.performQuantumSearch()

                    if self.returnedPressed == 2 {
                        self.addQuantum()
                        self.quantumState = QuantumState.editing
                    }
                    self.returnedPressed += 1
                case .editing:
                    print("in editing")
                    self.updateQuantum()
            }
            
            return true
        }
        return true
    }
    
    
// MARK: - Actions
    
    //Action Function for Left Button (Search, Save)
    @IBAction func clickedLeftButton(_ sender: AnyObject) {
        if let button = sender as? UIButton {
            //check if button lable it CLEAR, then clear text in UITextView
            //  reset the buttons to SEARCH left button and Add right button
            if button.titleLabel!.text! == "Search" {
                self.dismissKeyboard()
                self.performQuantumSearch()
            } else {
                //Update option
                self.updateQuantum()
            }
        }
    }
    
    //Action Function for Right Button (Add, Clear)
    @IBAction func clickedRightButton(_ sender: AnyObject) {
        //cast AnyObject to UIButton
        if let button = sender as? UIButton {
            //check if button label it CLEAR, then clear text in UITextView
            //  reset the buttons to SEARCH left button and Add right button
            if button.titleLabel!.text! == "Clear" {
                self.quantumTextView.text = ""
                //put cursor in UITextView -- focus
                self.quantumTextView.becomeFirstResponder()
                //reset labels of buttons
                self.leftButton.setTitle("Search", for: UIControlState())
                self.rightButton.setTitle("Add", for: UIControlState())
            } else {
                //add quantum to local db
                self.addQuantum()
            }
        }
    }
    
// MARK: - Homemade Functions
    
    
    //Generates a random GUID yyMMddHHmmss + a random number between 10001 and 28999
    // NOT USED ANYMORE
    fileprivate func getRandomID() -> String{
        let dateNow = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMddHHmmss" //format style. Browse online to get a format that fits your needs.
        
        //convert date to string
        let dateNowString = dateFormatter.string(from: dateNow)
        
        return "\(dateNowString)\(Int(arc4random_uniform(18999) + 10001))"
    }

    //Function that performs the quantum search
    func performQuantumSearch() {
        //clear array of quanta
        quantumList.removeAll()
        
        //Perform Full Text Search
        quantumList = quantumDB.fullTextSearchQuantum(self.quantumTextView.text)
        //if only one quanta found  loat it in the UITextView
        if quantumList.count == 1 {
            quantumTextView.text = quantumList[0].note
            //set labels of buttons for viewing quanta
            self.leftButton.setTitle("Save", for: UIControlState())
            self.rightButton.setTitle("Clear", for: UIControlState())
        }
        
        //reload tableview
        quantumListTableView.reloadData()
    }
    
    //Function to add quantum to local DB
    func addQuantum() {
        //Add Quantum option
        if self.quantumTextView.text.characters.count > 0 {
            let quantum = Quantum(id: UUID().uuidString.lowercased() , userID: "333333", note: self.quantumTextView.text, dateCreated: self.getDateNowInString(), dateUpdated: self.getDateNowInString(), deleted: false)
            
            quantumDB.insertQuantumToLocalDB(withQuantum: quantum)
            quantumList.insert(quantum, at: 0)
            quantumListTableView.reloadData()
            //button.setTitle("Quantum Added", forState: .Normal)
            self.leftButton.setTitle("Save", for: UIControlState())
            self.rightButton.setTitle("Clear", for: UIControlState())
            
            //TODO: add successful bool  - add to quantumList - alert not succesful error
            
        } else {
            //Save option
            print("text field empty add quantum")
        }
    }
    
    //Function to add quantum to local DB
    func updateQuantum() {
        let q = quantumList[quantumIndex]
        q.note = self.quantumTextView.text
        q.dateUpdated = self.getDateNowInString()
        quantumDB.updateQuantumInLocalDB(withQuantum: q)
        //reload tableview
        quantumListTableView.reloadData()
    }
    
    //Function executed when left swipe over UITextView is detected
    //  it clears the text from the UITextview, and resets labels of buttons
    func clearUITextView(_ sender:UITapGestureRecognizer) {
        //clear text in UITextView
        self.quantumTextView.text = ""
        self.returnedPressed = 0
        self.quantumState = QuantumState.adding
        //reset labels of buttons
        leftButton.setTitle("Search", for: UIControlState())
        rightButton.setTitle("Add", for: UIControlState())
        
        //put cursor in UITextView -- focus
        self.quantumTextView.becomeFirstResponder()
    }
    
    //Function for alert dialog
    //   currently not using
    func alertDialog(){
        let dialog = UIAlertController(title: "Can't Find Server",
                                       message: "Data will not be synced",
                                       preferredStyle: .alert)
        // Present the dialog.
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) {
            UIAlertAction in
            NSLog("OK Pressed")
        }
        
        dialog.addAction(okAction)
        // ... Do not worry about animated or completion for now.
        present(dialog,
                              animated: false,
                              completion: nil)
        
        let delay = 2.0 * Double(NSEC_PER_SEC)
        let time = DispatchTime.now() + Double(Int64(delay)) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time, execute: {
            dialog.dismiss(animated: true, completion: nil)
        })
    }
    
    //Function to get current date
    fileprivate func getDateNowInString() -> String {
        //format date for API call to get new quantums since last visit
        let dateNow = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" //format style. Browse online to get a format that fits your needs.
     
        //convert date to string
        return dateFormatter.string(from: dateNow)
        
    }

    
    
    // MARK: - TableViewControllers Functions
    
    //tableview number of rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return quantumList.count
    }
    
    //tableview Asks the data source for a cell to insert in a particular location of the table view.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return basicCellAtIndexPath(indexPath)
    }
    
    //tableview display row
    func basicCellAtIndexPath(_ indexPath:IndexPath) -> UITableViewCell {
        var cell : UITableViewCell! = quantumListTableView.dequeueReusableCell(withIdentifier: basicCellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: basicCellIdentifier)
        }
        let q = quantumList[(indexPath as NSIndexPath).row]
        //cell.textLabel!.numberOfLines = 2
        cell.textLabel!.text = q.note
        return cell
    }
    
    //tableview get row clicked
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.quantumTextView.text = quantumList[(indexPath as NSIndexPath).row].note
        self.quantumIndex = (indexPath as NSIndexPath).row
        self.quantumState = QuantumState.editing
        self.returnedPressed = 0
        self.dismissKeyboard()
        
        self.leftButton.setTitle("Save", for: UIControlState())
        self.rightButton.setTitle("Clear", for: UIControlState())
        
        print("clicked \((indexPath as NSIndexPath).row)")
    }

}

// MARK: - UIViewController Extensions
extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
}
