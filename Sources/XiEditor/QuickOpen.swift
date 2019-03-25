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

// MARK: Utility Classes
class QuickOpenTableView: NSTableView {
    override var needsPanelToBecomeKey: Bool { return true }
    override var acceptsFirstResponder: Bool { return false }
}

class QuickOpenSuggestionCellView: NSTableCellView {
    @IBOutlet weak var filenameTextField: NSTextField!
}

// MARK: - Quick Open Window Handling
class QuickOpenPanel: NSPanel {
    var quickOpenViewController: QuickOpenViewController? {
        return self.contentViewController as? QuickOpenViewController
    }

    // Required to receive keyboard input and events.
    override var canBecomeKey: Bool {
        return true
    }

    // Closes quick open panel immediately when losing focus.
    override func resignKey() {
        quickOpenViewController?.clearSuggestionsFromSearchField()
        self.close()
    }
}

// MARK: - Suggestions Table View Controller
class QuickOpenSuggestionsTableViewController: NSViewController {

    @IBOutlet weak var suggestionsTableView: QuickOpenTableView!
    @IBOutlet var suggestionsScrollView: NSScrollView!

    var testData = ["someFile.swift", "someOtherFile.swift", "thirdFile.swift"]
    let suggestionRowHeight = 30
    // Small margin, enough to hide the scrollbar.
    let suggestionMargin = 3
    // The maximum number of suggestions shown without scrolling.
    let maximumSuggestions = 6
    var maximumSuggestionHeight: Int {
        return maximumSuggestions * suggestionRowHeight
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        suggestionsTableView.focusRingType = .none
        suggestionsTableView.dataSource = self
        suggestionsTableView.delegate = self
        suggestionsTableView.target = self

        suggestionsTableView.wantsLayer = true
        suggestionsTableView.layer?.cornerRadius = 5
        suggestionsTableView.enclosingScrollView?.wantsLayer = true
        suggestionsTableView.enclosingScrollView?.layer?.cornerRadius = 5

        resizeTableView()
    }

    // Force table view to load all of its views on awake from nib.
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.view
    }

    // Resizes table view to fit suggestions.
    func resizeTableView() {
        let suggestionFrameHeight = min(testData.count * suggestionRowHeight + suggestionMargin, maximumSuggestionHeight)
        let suggestionFrameSize = NSSize(width: suggestionsScrollView.frame.width, height: CGFloat(suggestionFrameHeight))
        suggestionsScrollView.setFrameSize(suggestionFrameSize)
    }
}

extension QuickOpenSuggestionsTableViewController: NSTableViewDelegate, NSTableViewDataSource {

    fileprivate enum CellIdentifiers {
        static let FilenameCell = "FilenameCellID"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return testData.count
    }

    // Prevents gray highlights on the non-focused suggestion table view.
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = suggestionsTableView.selectedRow
        if let rowView = suggestionsTableView.rowView(atRow: selectedRow, makeIfNecessary: false) {
            rowView.selectionHighlightStyle = .regular
            rowView.isEmphasized = true
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text = ""
        var cellIdentifier = ""

        if tableColumn == tableView.tableColumns[0] {
            text = testData[row]
            cellIdentifier = CellIdentifiers.FilenameCell
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? QuickOpenSuggestionCellView {
            cell.filenameTextField.stringValue = text
            return cell
        }
        return nil
    }
}

// MARK: - Quick Open View Controller

protocol QuickOpenDelegate: class {
    func showQuickOpenSuggestions()
    func selectedQuickOpenSuggestion(atIndex index: Int)
    func closeQuickOpenSuggestions()
}

class QuickOpenViewController: NSViewController, NSSearchFieldDelegate {

    @IBOutlet weak var inputSearchField: NSSearchField!
    weak var quickOpenDelegate: QuickOpenDelegate!
    var suggestionTableViewController: QuickOpenSuggestionsTableViewController!
    var suggestionsTableView: QuickOpenTableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        suggestionTableViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Quick Open Suggestions Table View Controller")) as? QuickOpenSuggestionsTableViewController
        suggestionsTableView = suggestionTableViewController.suggestionsTableView
        inputSearchField.delegate = self
    }

    // MARK: Suggestion Management
    func showSuggestionsForSearchField() {
        // Attachs the suggestion table view to the top left corner of the search field.
        var screenRect = self.inputSearchField.convert(self.inputSearchField.frame, to: nil)
        screenRect = (self.view.window?.convertToScreen(screenRect))!
        let suggestionSize = NSSize(width: suggestionsTableView.frame.width, height: suggestionsTableView.frame.height + 30)
        self.view.window?.setContentSize(suggestionSize)
        self.view.addSubview(suggestionTableViewController.view)
    }

    func clearSuggestionsFromSearchField() {
        inputSearchField.stringValue = ""
        suggestionTableViewController.view.removeFromSuperview()
        let suggestionSize = NSSize(width: suggestionsTableView.frame.width, height: 30)
        self.view.window?.setContentSize(suggestionSize)
    }

    // Attaches the suggestion table view to the search field.
    override func controlTextDidBeginEditing(_ obj: Notification) {
        showSuggestionsForSearchField()
    }

    // Overrides keyboard commands when the quick open panel is currently showing.
    // Not very elegant, but it does the job for now.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        // ESC
        case #selector(cancelOperation(_:)):
            clearSuggestionsFromSearchField()
            quickOpenDelegate.closeQuickOpenSuggestions()
            return true
        // Up/Down
        case #selector(moveUp(_:)), #selector(moveDown(_:)):
            self.suggestionsTableView.keyDown(with: NSApp.currentEvent!)
            return true
        // Return/Enter
        case #selector(insertNewline(_:)):
            quickOpenDelegate?.selectedQuickOpenSuggestion(atIndex: self.suggestionsTableView.selectedRow)
            return true
        default:
            return false
        }
    }
}

extension EditViewController {
    // QuickOpenDelegate
    func showQuickOpenSuggestions() {
        quickOpenPanel = QuickOpenPanel(contentViewController: quickOpenViewController)
        quickOpenPanel.worksWhenModal = true
        quickOpenPanel.becomesKeyOnlyIfNeeded = true
        quickOpenPanel.styleMask = [.utilityWindow]
        quickOpenPanel.backgroundColor = .clear
        editView.window?.beginSheet(quickOpenPanel, completionHandler: nil)
    }

    func selectedQuickOpenSuggestion(atIndex index: Int) {
        print("do something with selected suggestion at \(index)")
    }

    func closeQuickOpenSuggestions() {
        // Cleanup on close or something
        editView.window?.endSheet(quickOpenPanel)
        print("quick open closed")
    }
}
