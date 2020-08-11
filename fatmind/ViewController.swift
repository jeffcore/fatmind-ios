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
    var counter = 0
   
    var quantumList = [Quantum]()
    let service = APIService()
    let quantumDB = QuantumDB()
    var userDefaults:UserDefaults!
    
// MARK: - ViewController Functions

    override func viewDidLoad() {
        super.viewDidLoad()
        userDefaults = UserDefaults.standard
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
        
        //saving every change in uitextview
//        let notificationCenter = NotificationCenter.default
//        notificationCenter.addObserver(self,
//                                       selector: Selector(("textFieldDidChange:")),
//                                       name: NSNotification.Name.UITextViewTextDidChange,
//                                       object: nil)
        
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
    //     any keypress saves
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        print("textchange before adding \(textView.text!)")
        
        let updatedString = (textView.text as NSString?)?.replacingCharacters(in: range, with: text)
       // self.quantumTextView.text = updatedString! as String
       // self.quantumTextView.selectedRange = NSMakeRange(range.location + range.length + 1, 0)
        
        print("textchange after adding \(updatedString!)")
        
        if text == "\n" {
            
            //covers case when return key is pressed
            switch quantumState {
                case .adding:
                    print("in adding return char")
                    self.returnedPressed += 1
                    self.performQuantumSearch()
                    //if return key is pressed twice a new quantume is created
                    if self.returnedPressed == 2 {
                        self.addQuantum()
                        self.quantumState = QuantumState.editing
                        self.returnedPressed = 0
                    }
                case .editing:
                    print("in editing return char")
                    //covers logic if return key is pressed in editing mode, just updates the quantum
                    self.updateQuantum(quantumText: nil)
                    self.returnedPressed = 0
            }
        } else {
           // self.quantumTextView.text = textView.text


            switch quantumState {
            case .adding:
                print("in adding other char")
                //creates a new quantum if return key was pressed once, followed by any other key
                if self.returnedPressed == 1 {
                    self.addQuantum()
                    self.quantumState = QuantumState.editing
                    self.returnedPressed = 0
                }
            case .editing:
                //updated if any other key is pressed while in editing mode
                print("in editing other char")
                self.updateQuantum(quantumText: updatedString)
                self.returnedPressed = 0
            }
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
                self.returnedPressed = 0
            } else {
                //Update option
                self.updateQuantum(quantumText: nil)
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
                 self.resetView()
            } else {
                //add quantum to local db
                self.addQuantum()
            }
        }
    }
    
// MARK: - Homemade Functions
    
    // Function text changed in the uitextview
//    func textFieldDidChange(sender : AnyObject) {
//            print("in text change notification")
//            if quantumState == .editing {
//                  self.updateQuantum()
//            }
//    }
//    
    
    
    //Function that performs the quantum search
    func performQuantumSearch() {
        //clear array of quantam
        quantumList.removeAll()
        
        //Perform Full Text Search
        quantumList = quantumDB.fullTextSearchQuantum(self.quantumTextView.text)
        //if only one quanta found  loat it in the UITextView
//        if quantumList.count == 1 {
//            quantumTextView.text = quantumList[0].note
//            //set labels of buttons for viewing quanta
//            self.leftButton.setTitle("Save", for: UIControlState())
//            self.rightButton.setTitle("Clear", for: UIControlState())
//        }
        
        //reload tableview
        quantumListTableView.reloadData()
    }
    
    //Function to add quantum to local DB
    func addQuantum() {
        //Add Quantum option
        if self.quantumTextView.text.count > 0 {
            
            print("counter vefore insert")
            print(counter)
            let quantum = Quantum(id: UUID().uuidString.lowercased() ,
                                  userID: "333333",
                                  note: self.quantumTextView.text,
                                  dateCreated: self.getDateNowInString(),
                                  dateUpdated: self.getDateNowInString(),
                                  deleted: false,
                                  counterSync: quantumDB.getCounterSync())
            
            quantumDB.insertQuantumToLocalDB(withQuantum: quantum)
            quantumDB.incrementCounterSync()
            //clear array of quanta
            quantumList.removeAll()
            quantumList.append(quantum)
            quantumIndex = 0
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
    func updateQuantum(quantumText text:String?) {
        print("update quantum funciton: quantum index is \(quantumIndex)" )
        let q = self.quantumList[quantumIndex]
        if let qText = text {
            q.note = qText
        } else {
            q.note = self.quantumTextView.text
        }
        q.dateUpdated = self.getDateNowInString()
        q.counterSync = self.quantumDB.getCounterSync()
        print("updateQuantum: counterSyncValue \(q.counterSync)")
        self.quantumDB.updateQuantumInLocalDB(withQuantum: q)
        self.quantumDB.incrementCounterSync()
        //reload tableview
        quantumListTableView.reloadData()
    }
    
    //Function executed when left swipe over UITextView is detected
    //  it clears the text from the UITextview, and resets labels of buttons
    @objc func clearUITextView(_ sender:UITapGestureRecognizer) {
        self.resetView()
    }
    
    
    func resetView() {
       print("cleared screen")
       //clear text in UITextView
       self.quantumTextView.text = ""
       self.returnedPressed = 0
       self.quantumState = QuantumState.adding
       self.quantumList.removeAll()
       quantumListTableView.reloadData()
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
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
