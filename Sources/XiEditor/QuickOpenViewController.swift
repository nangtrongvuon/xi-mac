// Copyright 2018 The xi-editor Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa

class QuickOpenPanel: NSPanel {
    // Required to receive keyboard input and events.
    override var canBecomeKey: Bool {
        return true
    }
}

class QuickOpenViewController: NSViewController, NSSearchFieldDelegate {

    @IBOutlet weak var inputSearchField: NSSearchField!
    var suggestionWindowController: QuickOpenSuggestionsWindowController!
    var suggestionTableViewController: QuickOpenSuggestionsTableViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        inputSearchField.delegate = self
        setup()

        let panel = NSPanel(contentViewController: suggestionTableViewController)
        suggestionWindowController = QuickOpenSuggestionsWindowController(window: panel)
    }

    func setup() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        suggestionTableViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Quick Open Suggestions Table View Controller")) as? QuickOpenSuggestionsTableViewController
    }

    override func mouseDown(with event: NSEvent) {
        self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: NSApplication.ModalResponse.OK)
    }

    override func controlTextDidBeginEditing(_ obj: Notification) {
        var screenRect = self.inputSearchField.convert(self.inputSearchField.frame, to: nil)
        screenRect = (self.view.window?.convertToScreen(screenRect))!

        let windowRect = NSRect(origin: .zero, size: CGSize(width: inputSearchField.frame.width, height: suggestionWindowController.window!.frame.height))

        suggestionWindowController.window!.setFrame(windowRect, display: false)
        suggestionWindowController.window!.setFrameTopLeftPoint(screenRect.origin)
        self.view.window?.addChildWindow(suggestionWindowController.window!, ordered: .above)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            self.view.window?.sheetParent?.endSheet(self.view.window!, returnCode: NSApplication.ModalResponse.OK)
            return true
        } else {
            return false
        }
    }
}
