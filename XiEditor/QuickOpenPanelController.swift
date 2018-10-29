//
//  QuickOpenPanelController.swift
//  XiEditor
//
//  Created by Dzũng Lê on 10/29/18.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

class QuickOpenPanelController: NSWindowController {

    weak var quickOpenViewController: QuickOpenViewController?
    weak var editViewController: EditViewController?

    override init(window: NSWindow?) {
        super.init(window: window)
        if let panel = window as? NSPanel {
            panel.styleMask = [.docModalWindow]
            panel.isOpaque = false
            panel.level = .floating
            panel.hidesOnDeactivate = true
        }
    }

    func showQuickOpen() {
        guard let window = editViewController!.view.window else { return }
        window.beginSheet(self.window!, completionHandler: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
