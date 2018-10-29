//
//  QuickOpenViewController.swift
//  XiEditor
//
//  Created by Dzũng Lê on 10/29/18.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

class QuickOpenViewController: NSViewController {

    @IBOutlet weak var inputTextField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    @IBAction func okButtonPressed(_ sender: Any) {
        self.dismiss(sender)
    }

    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.dismiss(sender)
    }
}
