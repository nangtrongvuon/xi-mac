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
    override var isFlipped: Bool { return true }
}

class QuickOpenSuggestionRowView: NSTableRowView {
    @IBOutlet weak var fileNameLabel: NSTextField!
    @IBOutlet weak var fullPathLabel: NSTextField!

    // Keeps the focused color on our table view rows, since we don't actually focus on it.
    override var isEmphasized: Bool {
        get { return true }
        // Does nothing, just here so we can override the getter
        set { }
    }

    // Allows us to get some custom highlighting in.
    override func drawSelection(in dirtyRect: NSRect) {
        super.drawSelection(in: dirtyRect)

        NSColor.alternateSelectedControlColor.set()
        let rect = NSRect(x: 0, y: bounds.height - 2, width: bounds.width, height: bounds.height)
        let path = NSBezierPath(rect: rect)
        path.fill()
    }
    
    /// Configures this view with data from a completion.
    func configure(withCompletion completion: FuzzyCompletion) {
        let fileURL = URL(fileURLWithPath: completion.path)
        let fullPath = fileURL.relativeString
        let fileName = fileURL.lastPathComponent
        
        self.fileNameLabel.stringValue = fileName
        self.fullPathLabel.stringValue = fullPath
    }
}

// MARK: Protocols
protocol QuickOpenDelegate: class {
    func showQuickOpenSuggestions()
    func sendQuickOpenRequest(query: String)
    func didSelectQuickOpenCompletion(with completion: FuzzyCompletion)
    func closeQuickOpenSuggestions()
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

    @IBOutlet var suggestionsTableView: QuickOpenTableView!
    @IBOutlet var suggestionsScrollView: NSScrollView!
    
    weak var quickOpenViewController: QuickOpenViewController?
    weak var quickOpenSuggestionController: QuickOpenSuggestionController? {
        return self.suggestionsTableView.dataSource as? QuickOpenSuggestionController
    }

    /// The current height of the suggestions table view.
    /// This can go up to the `maximumSuggestionHeight` defined below.
    var suggestionFrameHeight: CGFloat {
        if let suggestionController = quickOpenSuggestionController {
            var calculatedHeight = CGFloat(suggestionsTableView.numberOfRows) * suggestionRowHeight
            if calculatedHeight >= maximumSuggestionHeight {
                calculatedHeight = maximumSuggestionHeight
            }
            return calculatedHeight    
        } else {
            return 0
        }
    }

    /// Height for each row in the suggestion table view.
    let suggestionRowHeight: CGFloat = 60
    /// The maximum number of suggestions shown without scrolling.
    let maximumSuggestions = 6

    /// The tallest height that the suggestion can be.
    /// Currently capped to 6, which is similar to other editors.
    var maximumSuggestionHeight: CGFloat {
        return CGFloat(maximumSuggestions) * suggestionRowHeight
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.suggestionsTableView.delegate = self
        self.suggestionsTableView.target = self
        self.view.wantsLayer = true
        self.view.layer?.cornerRadius = 6
    }

    // Force table view to load all of its views on awake from nib.
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.view
    }
}

// MARK: Suggestion Table View Controller Delegates
extension QuickOpenSuggestionsTableViewController: NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let FilenameCell = "FilenameCellID"
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        enum CellIdentifiers {
            static let FilenameCell = "FilenameCellID"
        }
        let rowIdentifier = CellIdentifiers.FilenameCell
        
        if let rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: rowIdentifier), owner: nil) as? QuickOpenSuggestionRowView {
            if let completion = quickOpenSuggestionController?.getSuggestion(at: row) {
                rowView.configure(withCompletion: completion)
                return rowView    
            }
        }
        return nil
    }
}

// MARK: - Quick Open Suggestion Manager
/// Handles quick open suggestions' data and states.
class QuickOpenSuggestionController: NSObject, NSTableViewDataSource {
    private var currentCompletions = [FuzzyCompletion]()
    var quickOpenViewController: QuickOpenViewController

    override init() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Quick Open View Controller")) as! QuickOpenViewController
        self.quickOpenViewController = controller
        super.init()
        controller.quickOpenSuggestionController = self
    }
    
    /// Clear all completions.
    func clearCompletions() {
        currentCompletions.removeAll()
    }

    /// Parse received completions from core.
    func updateCompletions(completions: [FuzzyCompletion]) {
        // Override all current completions.
        currentCompletions = completions
        quickOpenViewController.showSuggestionsForSearchField()
    }
    
    func getSuggestion(at index: Int) -> FuzzyCompletion {
        return currentCompletions[index]
    }
    
    // MARK: NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return currentCompletions.count
    }
}

// MARK: - Quick Open View Controller
class QuickOpenViewController: NSViewController, NSSearchFieldDelegate {
    @IBOutlet weak var inputSearchField: NSSearchField!

    weak var quickOpenSuggestionController: QuickOpenSuggestionController?
    weak var quickOpenDelegate: QuickOpenDelegate!
    var suggestionTableViewController: QuickOpenSuggestionsTableViewController!
    var suggestionsTableView: QuickOpenTableView {
        return suggestionTableViewController.suggestionsTableView
    }
    
    var suggestionSize: NSSize {
        return NSSize(width: self.view.frame.width, 
                      height: suggestionTableViewController.suggestionFrameHeight + inputSearchField.frame.height)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        inputSearchField.delegate = self
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier {
            if identifier == "SuggestionTableViewControllerSegue" {
                let controller = segue.destinationController as! QuickOpenSuggestionsTableViewController
                suggestionTableViewController = controller
                suggestionTableViewController.suggestionsTableView.dataSource = self.quickOpenSuggestionController
            }
        }
    }

    // MARK: Suggestion Management
    func showSuggestionsForSearchField() {
        self.suggestionsTableView.reloadData()
        self.view.window?.setContentSize(suggestionSize)
    }

    func clearSuggestionsFromSearchField() {
        inputSearchField.stringValue = ""
        self.view.window?.setContentSize(suggestionSize)
    }
    
    func selectSuggestion(atIndex index: Int) {
        if let suggestionController = self.quickOpenSuggestionController {
            let selectedCompletion = suggestionController.getSuggestion(at: index)
            self.quickOpenDelegate?.didSelectQuickOpenCompletion(with: selectedCompletion)
        }
    }

    // Refreshes quick open suggestion on type.
    func controlTextDidChange(_ obj: Notification) {
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
            let selectedCompletionIndex = self.suggestionsTableView.selectedRow
            self.selectSuggestion(atIndex: selectedCompletionIndex)
            return true
            
        default:
            return false
        }
    }
}

// MARK: QuickOpenDelegate
extension EditViewController {
    func showQuickOpenSuggestions() {
        editView.window?.beginSheet(quickOpenPanel, completionHandler: nil)
    }
    
    func closeQuickOpenSuggestions() {
        // Cleanup on close or something
        editView.window?.endSheet(quickOpenPanel)
        print("quick open closed")
    }

    func sendQuickOpenRequest(query: String) {
        xiView.sendQuickOpenRequest(query: query)
    }

    func didSelectQuickOpenCompletion(with completion: FuzzyCompletion) {
        let completionPath = URL(fileURLWithPath: completion.path)
        NSDocumentController.shared.openDocument(
            withContentsOf: completionPath,
            display: true,
            completionHandler: { (document, alreadyOpen, error) in
                if let error = error {
                    print("error quick opening file \(error)")
                }
        })
    }
}
