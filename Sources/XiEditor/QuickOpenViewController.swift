//
//  QuickOpenViewController.swift
//  XiEditor
//
//  Created by Dzũng Lê on 10/29/18.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

class QuickOpenPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

class QuickOpenViewController: NSViewController {

    @IBOutlet weak var inputTextField: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    @IBAction func okButtonPressed(_ sender: Any) {
        self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: NSApplication.ModalResponse.OK)
    }

    @IBAction func cancelButtonPressed(_ sender: Any) {
        self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: NSApplication.ModalResponse.OK)
    }

    override func mouseDown(with event: NSEvent) {
        self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: NSApplication.ModalResponse.OK)
    }
}
