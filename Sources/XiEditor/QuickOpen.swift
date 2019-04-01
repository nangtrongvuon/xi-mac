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

// MARK: Protocols
protocol QuickOpenDelegate: class {
    func activateQuickOpenPanel()
    func sendQuickOpenRequest(query: String)
    func showQuickOpenSuggestions()
    func selectedQuickOpenSuggestion(atIndex index: Int)
    func closeQuickOpenSuggestions()
}

protocol QuickOpenDataSource: class {
    func refreshCompletions(newCompletions: [FuzzyCompletion])
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
        // Avoids double calling the cleanup methods - closing the panel seems to call
        // `resignKey` again.
        if self.isVisible {
            quickOpenViewController?.clearSuggestionsFromSearchField()
            quickOpenViewController?.quickOpenDelegate.closeQuickOpenSuggestions()
        }
    }
}

// MARK: - Suggestions Table View Controller
class QuickOpenSuggestionsTableViewController: NSViewController {
    @IBOutlet weak var suggestionsTableView: QuickOpenTableView!
    @IBOutlet var suggestionsScrollView: NSScrollView!

    var testData = ["someFile.swift", "someOtherFile.swift", "thirdFile.swift"]
    fileprivate var completions = [FuzzyCompletion]() {
        didSet {
            suggestionsTableView.reloadData()
            resizeTableView()
        }
    }

    // The current height of the suggestions table view.
    // This can go up to the `maximumSuggestionHeight` defined below.
    var suggestionFrameHeight: CGFloat = 0
    var maximumSuggestionHeight: CGFloat {
        return CGFloat(maximumSuggestions) * suggestionRowHeight
    }
    // Height for each row in the suggestion table view.
    let suggestionRowHeight: CGFloat = 30
    // Small margin, enough to hide the scrollbar.
    let suggestionMargin: CGFloat = 3
    // The maximum number of suggestions shown without scrolling.
    let maximumSuggestions = 6

    override func viewDidLoad() {
        super.viewDidLoad()

        suggestionsTableView.focusRingType = .none
        suggestionsTableView.delegate = self
        suggestionsTableView.dataSource = self
        suggestionsTableView.target = self

        suggestionsTableView.wantsLayer = true
        suggestionsTableView.layer?.cornerRadius = 5
        suggestionsTableView.enclosingScrollView?.wantsLayer = true
        suggestionsTableView.enclosingScrollView?.layer?.cornerRadius = 5
    }

    // Force table view to load all of its views on awake from nib.
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.view
    }

    // Resizes table view to fit suggestions.
    func resizeTableView() {
        suggestionFrameHeight = min(CGFloat(completions.count) * suggestionRowHeight + suggestionMargin, maximumSuggestionHeight)
        let suggestionFrameSize = NSSize(width: suggestionsScrollView.frame.width, height: suggestionFrameHeight)
        suggestionsScrollView.setFrameSize(suggestionFrameSize)
    }
}

extension QuickOpenSuggestionsTableViewController: NSTableViewDelegate, NSTableViewDataSource {

    fileprivate enum CellIdentifiers {
        static let FilenameCell = "FilenameCellID"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return completions.count
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
            text = completions[row].path
            cellIdentifier = CellIdentifiers.FilenameCell
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? QuickOpenSuggestionCellView {
            cell.filenameTextField.stringValue = text
            return cell
        }
        return nil
    }
}

// MARK: - Quick Open Manager

// A possible quick open completion.
struct FuzzyCompletion {
    let path: String
    let score: Int
}

// Handles quick open data and states.
class QuickOpenManager {
    var currentCompletions = [FuzzyCompletion]()

    // Parse received completions from core.
    func updateCompletions(rawCompletions: [[String: AnyObject]]) {
        for rawCompletion in rawCompletions {
            let completionPath = rawCompletion["result_name"] as! String
            let completionScore = rawCompletion["score"] as! Int
            let newCompletion = FuzzyCompletion(path: completionPath, score: completionScore)
            currentCompletions.append(newCompletion)
        }
    }
}

// MARK: - Quick Open View Controller
class QuickOpenViewController: NSViewController, NSSearchFieldDelegate {
    @IBOutlet weak var inputSearchField: NSSearchField!

    weak var quickOpenDelegate: QuickOpenDelegate!
    let quickOpenManager = QuickOpenManager()
    var suggestionTableViewController: QuickOpenSuggestionsTableViewController!
    var suggestionsTableView: QuickOpenTableView {
        return suggestionTableViewController.suggestionsTableView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        suggestionTableViewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Quick Open Suggestions Table View Controller")) as? QuickOpenSuggestionsTableViewController
        inputSearchField.delegate = self
    }

    // MARK: Suggestion Management
    func updateCompletions(newCompletions: [[String: AnyObject]]) {
        quickOpenManager.updateCompletions(rawCompletions: newCompletions)
        suggestionTableViewController.completions = quickOpenManager.currentCompletions
        showSuggestionsForSearchField()
    }

    func showSuggestionsForSearchField() {
        let suggestionSize = NSSize(width: suggestionsTableView.frame.width, height: suggestionTableViewController.suggestionFrameHeight + inputSearchField.frame.height)
        self.view.window?.setContentSize(suggestionSize)
        self.view.addSubview(suggestionTableViewController.view)
    }

    func clearSuggestionsFromSearchField() {
        inputSearchField.stringValue = ""
        suggestionTableViewController.view.removeFromSuperview()
        let suggestionSize = NSSize(width: suggestionsTableView.frame.width, height: inputSearchField.frame.height)
        self.view.window?.setContentSize(suggestionSize)
    }

    // Refreshes quick open suggestion on type.
    override func controlTextDidChange(_ obj: Notification) {
        sendCurrentQuery()
    }

    @objc func sendCurrentQuery() {
        let query = self.inputSearchField.stringValue
        quickOpenDelegate.sendQuickOpenRequest(query: query)
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

// MARK: QuickOpenDelegate
extension EditViewController {
    func activateQuickOpenPanel() {
        editView.window?.beginSheet(quickOpenPanel, completionHandler: nil)
    }

    func sendQuickOpenRequest(query: String) {
        xiView.sendQuickOpenRequest(query: query)
    }

    func showQuickOpenSuggestions() {
        print("do stuff once core sends back stuff")
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
