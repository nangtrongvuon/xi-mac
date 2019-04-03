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

class QuickOpenSuggestionRowView: NSTableRowView {
    @IBOutlet weak var fileNameLabel: NSTextField!
    @IBOutlet weak var fullPathLabel: NSTextField!

    // Keeps the focused color on our table view rows, since we don't actually focus on it.
    override var isEmphasized: Bool {
        get { return true }
        set {
            // Does nothing, just here so we can override the getter
        }
    }
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
    let suggestionRowHeight: CGFloat = 45
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

        self.view.wantsLayer = true
        self.view.layer?.cornerRadius = 6
    }

    // Force table view to load all of its views on awake from nib.
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.view
    }

    // Resizes table view to fit suggestions.
    func resizeTableView() {
        suggestionFrameHeight = min(CGFloat(completions.count) * suggestionRowHeight, maximumSuggestionHeight)
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

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return suggestionRowHeight
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        var fileName = ""
        var fullPath = ""
        var rowIdentifier = ""

        let fileURL = URL(fileURLWithPath: completions[row].path)
        fullPath = fileURL.relativeString
        fileName = fileURL.lastPathComponent
        rowIdentifier = CellIdentifiers.FilenameCell

        if let rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: rowIdentifier), owner: nil) as? QuickOpenSuggestionRowView {
            rowView.fileNameLabel.stringValue = fileName
            rowView.fullPathLabel.stringValue = fullPath
            rowView.backgroundColor = .clear
            return rowView
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
    var quickOpenViewController: QuickOpenViewController

    init() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "Quick Open View Controller")) as! QuickOpenViewController
        self.quickOpenViewController = controller
        self.quickOpenViewController.quickOpenManager = self
    }

    // Parse received completions from core.
    func updateCompletions(rawCompletions: [[String: AnyObject]]) {
        for rawCompletion in rawCompletions {
            let completionPath = rawCompletion["result_name"] as! String
            let completionScore = rawCompletion["score"] as! Int
            let newCompletion = FuzzyCompletion(path: completionPath, score: completionScore)
            currentCompletions.append(newCompletion)
        }

        quickOpenViewController.suggestionTableViewController.completions = currentCompletions
        quickOpenViewController.showSuggestionsForSearchField()
    }
}

// MARK: - Quick Open View Controller
class QuickOpenViewController: NSViewController, NSSearchFieldDelegate {
    @IBOutlet weak var inputSearchField: NSSearchField!

    weak var quickOpenManager: QuickOpenManager?
    weak var quickOpenDelegate: QuickOpenDelegate!
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
    func showSuggestionsForSearchField() {
        let suggestionSize = NSSize(width: self.view.frame.width, height: suggestionTableViewController.suggestionFrameHeight + inputSearchField.frame.height)
        self.view.window?.setContentSize(suggestionSize)
        self.view.addSubview(suggestionTableViewController.view)
    }

    func clearSuggestionsFromSearchField() {
        inputSearchField.stringValue = ""
        let suggestionSize = NSSize(width: self.view.frame.width, height: suggestionTableViewController.suggestionFrameHeight + inputSearchField.frame.height)
        self.view.window?.setContentSize(suggestionSize)
        suggestionTableViewController.view.removeFromSuperview()
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
