//
//  ViewController.swift
//  SpeechToTextRecognition
//
//  Created by Pradeep on 21/03/20.
//  Copyright © 2020 Pradeep. All rights reserved.
//

import UIKit

import Speech

import SwiftyWave

class ViewController: UIViewController {
    
    enum SpeechStatus {
        case ready
        case recognizing
        case unavailable
    }
    
    // MARK: - Properties Declaration -
    
    @IBOutlet weak var speechTextView: UITextView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var micButton: UIButton!
    
    @IBOutlet weak var keywordSearchView: UIView!
    @IBOutlet weak var keyWordTextField: UITextField!
    @IBOutlet weak var defineKeywordsTextView: UITextView!
    @IBOutlet weak var keyWordsFoundTextView: UITextView!
    
    @IBOutlet weak var waveView: SwiftyWaveView!
    
    var fullSpeechString:String = ""
    var stringWithMatchedKeywords = ""
    var searchString:String = ""
    
    var arrayWithAllTheKeywords:[String] = []
    
    let audioEngine = AVAudioEngine()
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    let request = SFSpeechAudioBufferRecognitionRequest()
    var recognitionTask:SFSpeechRecognitionTask?
    
    var status = SpeechStatus.ready {
        didSet {
        }
    }
    
    // MARK:- Method Definitions -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        keywordSearchView.isHidden = true
        
        waveView.isHidden = true
        
        titleLabel.text = "Start Mic!!!"
        
        keyWordTextField.delegate = self
        
        speechTextView.layer.cornerRadius = speechTextView.frame.size.height/2
        speechTextView.clipsToBounds = false
        speechTextView.layer.shadowOpacity = 0.4
        speechTextView.layer.shadowOffset = CGSize(width: 3, height: 3)
        
        let borderColor = UIColor.white
        
        speechTextView.layer.borderColor = borderColor.cgColor;
        speechTextView.layer.borderWidth = 1.0;
        speechTextView.layer.cornerRadius = 5.0;
        
        micButton.layer.shadowColor = UIColor(red: 0.9, green: 0.0, blue: 0.0, alpha: 0.55).cgColor
        micButton.layer.shadowOffset = CGSize(width: 3, height: 3)
        micButton.layer.shadowOpacity = 4.0
        micButton.layer.shadowRadius = 10.0
        micButton.layer.masksToBounds = false
        
        keyWordTextField.attributedPlaceholder = NSAttributedString(string: "Type your keywords here", attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
        
        requestAndCheckSpeechAuthorization()
        
        //Looks for single or multiple taps.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        
        //Uncomment the line below if you want the tap not not interfere and cancel other interactions.
        //tap.cancelsTouchesInView = false
        
        view.addGestureRecognizer(tap)
    }
    
    //Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    func requestAndCheckSpeechAuthorization() {
        
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            self.askSpeechPermission()
        case .authorized:
            self.status = .ready
        case .denied, .restricted:
            self.status = .unavailable
        @unknown default:
            fatalError()
        }
    }
    
    /// Ask permission to the user to access their speech data.
    func askSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            OperationQueue.main.addOperation {
                switch status {
                case .authorized:
                    self.status = .ready
                default:
                    self.status = .unavailable
                }
            }
        }
    }
    
    @IBAction func onTapOfMicButton(_ sender: UIButton) {
        
        switch status {
            
        case .ready:
            resetTextForNewSpeech()
            recordAndRecognizeSpeech()
        case .recognizing:
            resetTextAfterRecognitionIsCompleted()
            cancelRecording()
        default:
            break
        }
    }
    
    func recordAndRecognizeSpeech(){
        
        waveView.isHidden = false
        waveView.start()
        
        self.view.bringSubviewToFront(micButton)
        
        let node = audioEngine.inputNode
        let recodingFormat = node.outputFormat(forBus: 0)
        
        node.installTap(onBus: 0,
                        bufferSize: 1024,
                        format: recodingFormat) {
                            (buffer, _) in
                            self.request.append(buffer)
        }
        
        self.audioEngine.prepare()
        
        do{
            try self.audioEngine.start()
            self.status = .recognizing
        }catch{
            return print(error)
        }
        
        guard let myRecognizer = SFSpeechRecognizer() else {
            return
        }
        
        if !myRecognizer.isAvailable{
            return
        }
        
        self.recognitionTask = self.speechRecognizer?.recognitionTask(with: self.request, resultHandler: { (result, error) in
            
            if let result = result{
                
                let bestString = result.bestTranscription.formattedString
                self.speechTextView.text = bestString
                self.fullSpeechString = bestString
                print(self.fullSpeechString)
                
            }else if let error = error{
                print(error)
            }
        })
    }
    
    func cancelRecording() {
        
        waveView.isHidden = true
        waveView.stop()
        
        audioEngine.stop()
        request.endAudio()
        let node = audioEngine.inputNode
        node.removeTap(onBus: 0)
        recognitionTask?.cancel()
        titleLabel.text = "Start Mic!!!"
        print("The final string after cancelling is \(fullSpeechString)")
    }
    
    func resetTextForNewSpeech(){
        
        status = .recognizing
        
        titleLabel.text = "Stop Mic!!!"
        
        micButton.isSelected = true
        keywordSearchView.isHidden = true
        
        searchString = ""
        stringWithMatchedKeywords = ""
        
        arrayWithAllTheKeywords.removeAll()
        
        speechTextView.text = ""
        defineKeywordsTextView.text = ""
        keyWordsFoundTextView.text = ""
    }
    
    func resetTextAfterRecognitionIsCompleted(){
        status = .ready
        micButton.isSelected = false
        keywordSearchView.isHidden = false
    }
    
    func displayKeywords(){
        
        var searchString = ""
        
        for string in arrayWithAllTheKeywords{
            searchFullSpeech(with: string)

            if searchString.isEmpty {
                
                searchString = "\(string)"
                
            } else {
                
                //                if !searchString.contains(string){
                /*Along the way of saving the keywords, try finding if the saved keyword is present in full speech search*/
                //                    searchFullSpeech(with: string)
                
                searchString = "\(string),\(searchString)"
                //                }
            }
        }
        
        print(searchString)
        defineKeywordsTextView.text = searchString
    }
    
    func searchFullSpeech(with keywordString:String){
        
        if fullSpeechString.lowercased().contains(keywordString) {
            
            if stringWithMatchedKeywords.isEmpty {
                stringWithMatchedKeywords = keywordString
            }else{
                if !stringWithMatchedKeywords.contains(keywordString) {
                    stringWithMatchedKeywords = "\(keywordString),\(stringWithMatchedKeywords)"
                }
            }
            keyWordsFoundTextView.text = stringWithMatchedKeywords
        }
    }
}

// MARK: - TextField Delegate Methods -

extension ViewController:UITextFieldDelegate{
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        if let keyWordString = textField.text{
            
            //            /*Remove empty spaces before adding the keyword*/
            //            let trimmedKeyword = keyWordString.trimmingCharacters(in: .whitespaces).lowercased()
            
            /*Check if the keyword typed is Empty. Add it to the Array only a keyword is typed*/
            if !keyWordString.isEmpty{
                
                let strArray = keyWordString.components(separatedBy: ",")
                
                for trimmedKeyword in strArray {
                    
                    let trimmedKeyword = trimmedKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    
                    if trimmedKeyword.isEmpty {
                        continue;
                    }
                    /*Add the First keyword directly to the Array*/
                    if arrayWithAllTheKeywords.isEmpty{
                        
                        arrayWithAllTheKeywords.append(trimmedKeyword)
                    }
                    else{
                        /*Loop between the keywords and avoid adding the keyword if it is already added to the array*/
                        
                        if !arrayWithAllTheKeywords.contains(trimmedKeyword){
                            
                            
                            
                            arrayWithAllTheKeywords.append(trimmedKeyword)
                        }
                    }
                }
            }
        }
        
        print(arrayWithAllTheKeywords)
        
        displayKeywords()
        
        keyWordTextField.text = ""
    }
}

// MARK: - SpeechRecognizerDelegate -

extension ViewController:SFSpeechRecognizerDelegate{
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        
    }
}

extension String{
    
    func isPresent(in searchString:String) -> Bool{
        
        if self.lowercased().contains(searchString){
            return true
        }else{
            return false
        }
    }
}

