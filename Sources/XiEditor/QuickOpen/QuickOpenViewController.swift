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

protocol QuickOpenDelegate: class {
    func showQuickOpenSuggestions()
    func selectedQuickOpenSuggestion(atIndex index: Int)
    func closeQuickOpenSuggestions()
}

class QuickOpenViewController: NSViewController, NSSearchFieldDelegate {

    @IBOutlet weak var inputSearchField: NSSearchField!
    weak var quickOpenDelegate: QuickOpenDelegate!
    var suggestionWindowController: QuickOpenSuggestionsWindowController!
    var suggestionTableViewController: QuickOpenSuggestionsTableViewController!
    var suggestionsTableView: QuickOpenTableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        inputSearchField.delegate = self

        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        suggestionTableViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Quick Open Suggestions Table View Controller")) as? QuickOpenSuggestionsTableViewController
        suggestionsTableView = suggestionTableViewController.suggestionsTableView

        let panel = NSPanel(contentViewController: suggestionTableViewController)
        suggestionWindowController = QuickOpenSuggestionsWindowController(window: panel)
    }

    // MARK: - Suggestion Management
    func showSuggestionsForSearchField() {
        /// Attachs the suggestion table view to the top left corner of the search field.
        var screenRect = self.inputSearchField.convert(self.inputSearchField.frame, to: nil)
        screenRect = (self.view.window?.convertToScreen(screenRect))!

        let windowRect = NSRect(origin: .zero, size: CGSize(width: inputSearchField.frame.width, height: suggestionWindowController.window!.frame.height))

        suggestionWindowController.window!.setFrame(windowRect, display: false)
        suggestionWindowController.window!.setFrameTopLeftPoint(screenRect.origin)
        suggestionTableViewController.resizeTableView()

        self.view.window?.addChildWindow(suggestionWindowController.window!, ordered: .above)
    }

    func clearSuggestionsFromSearchField() {
        inputSearchField.stringValue = ""
        self.view.window?.removeChildWindow(suggestionWindowController.window!)
    }

    /// Attaches the suggestion table view to the search field.
    override func controlTextDidBeginEditing(_ obj: Notification) {
        showSuggestionsForSearchField()
    }

    // MARK: - Handle panel commands
    /// Closes panel when clicking outside of it.
    override func mouseDown(with event: NSEvent) {
        clearSuggestionsFromSearchField()
        quickOpenDelegate.closeQuickOpenSuggestions()
    }

    /// Overrides keyboard commands when the quick open panel is currently showing.
    /// Not very elegant, but it does the job for now.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        /// ESC
        case #selector(cancelOperation(_:)):
            clearSuggestionsFromSearchField()
            quickOpenDelegate.closeQuickOpenSuggestions()
            return true
        /// Up/Down
        case #selector(moveUp(_:)), #selector(moveDown(_:)):
            self.suggestionsTableView.keyDown(with: NSApp.currentEvent!)
            return true
        /// Return/Enter
        case #selector(insertNewline(_:)):
            quickOpenDelegate.selectedQuickOpenSuggestion(atIndex: self.suggestionsTableView.selectedRow)
            return true
        default:
            return false
        }
    }
}

extension EditViewController {
    /// QuickOpenDelegate
    func showQuickOpenSuggestions() {
        editView.window?.beginSheet(quickOpenPanel, completionHandler: nil)
    }

    func selectedQuickOpenSuggestion(atIndex index: Int) {
        print("do something with selected suggestion at \(index)")
    }

    func closeQuickOpenSuggestions() {
        editView.window?.endSheet(quickOpenPanel)
    }
}
