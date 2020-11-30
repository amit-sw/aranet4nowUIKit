//
//  SettingsVC.swift
//  aranet4nowUIKit
//
//  Created by Amit Gupta on 11/27/20.
//

import UIKit
import Firebase
import FirebaseUI
import GoogleSignIn


class SettingsViewController: UIViewController {

    // @IBOutlet weak var feedbackText: UITextView!
    
    @IBOutlet weak var feedbackText: UITextView!
    //@IBOutlet weak var feedbackText: UITextField!
    
    @IBOutlet weak var submitButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    

    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        feedbackText.resignFirstResponder()
    }
    
    
    @IBAction func submitPressed(_ sender: Any) {
        print("Button pressed")
        let db=Firestore.firestore()
        db.collection("CO2TestV01").addDocument(data: ["currentDate":Date(), "recordType":"Feedback", "comments":feedbackText.text!])
        feedbackText.text=""
        navigationController?.popToRootViewController(animated: true)
    }
    
}
