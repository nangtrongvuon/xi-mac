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

class QuickOpenCompletionRowView: NSTableRowView {
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
        let fileName = fileURL.lastPathComponent
        let fullPath = completion.path
        
        let filePathAttributedString = NSMutableAttributedString(string: fileName)
        self.fileNameLabel.attributedStringValue = filePathAttributedString
        self.fullPathLabel.stringValue = fullPath
    }
    
    /// Highlight matching quick open characters as they are typed.
    func highlightMatchingCharacters(withQuery query: String) {
        // Find where this cell's character appears in the query
        
    }
}

// MARK: Protocols
protocol QuickOpenDelegate: class {
    func showQuickOpenCompletionPanel()
    func sendQuickOpenRequest(query: String)
    func didSelectQuickOpenCompletion(with completion: FuzzyCompletion)
    func closeQuickOpenCompletionPanel()
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
            quickOpenViewController?.clearCompletions()
            quickOpenViewController?.quickOpenDelegate.closeQuickOpenCompletionPanel()
        }
    }
}

// MARK: - Quick Open Completions Table View Controller
class QuickOpenCompletionTableViewController: NSViewController {

    @IBOutlet var completionTableView: QuickOpenTableView!
    @IBOutlet var completionScrollView: NSScrollView!
    
    weak var quickOpenViewController: QuickOpenViewController?
    weak var quickOpenCompletionController: QuickOpenCompletionController? {
        return self.completionTableView.dataSource as? QuickOpenCompletionController
    }

    /// The current height of the completion table view.
    /// This can go up to the `maximumCompletionTableViewHeight` defined below.
    var calculatedTableViewHeight: CGFloat {
        var calculatedHeight = CGFloat(completionTableView.numberOfRows) * completionRowHeight
        if calculatedHeight >= maximumCompletionTableViewHeight {
            calculatedHeight = maximumCompletionTableViewHeight
        }
        return calculatedHeight    
    }
    
    /// Height for each row in the completion table view.
    let completionRowHeight: CGFloat = 60
    /// The maximum number of completions shown without scrolling.
    let maximumCompletions = 6

    /// The tallest height that the completion can be.
    /// Currently capped to 6, which is similar to other editors.
    var maximumCompletionTableViewHeight: CGFloat {
        return CGFloat(maximumCompletions) * completionRowHeight
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.completionTableView.delegate = self
        self.completionTableView.target = self
        self.view.wantsLayer = true
        self.view.layer?.cornerRadius = 6 // 6 is considered to be the native corner radius.
    }

    // Force table view to load all of its views on awake from nib.
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.view
    }
}

// MARK: Quick Open Completion Table View Controller Delegates
extension QuickOpenCompletionTableViewController: NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let FilenameCell = "FilenameCellID"
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        enum CellIdentifiers {
            static let FilenameCell = "FilenameCellID"
        }
        let rowIdentifier = CellIdentifiers.FilenameCell
        
        if let rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: rowIdentifier), owner: nil) as? QuickOpenCompletionRowView {
            if let completion = quickOpenCompletionController?.getCompletion(at: row) {
                rowView.configure(withCompletion: completion)
                return rowView    
            }
        }
        return nil
    }
}

// MARK: - Quick Open Completion Manager
/// Handles quick open completions data and states.
class QuickOpenCompletionController: NSObject, NSTableViewDataSource {
    private var currentCompletions = [FuzzyCompletion]()
    var quickOpenViewController: QuickOpenViewController

    override init() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let controller = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Quick Open View Controller")) as! QuickOpenViewController
        self.quickOpenViewController = controller
        super.init()
        controller.quickOpenCompletionController = self
    }
    
    /// Clear all completions.
    func clearCompletions() {
        currentCompletions.removeAll()
    }

    /// Parse received completions from core.
    func updateCompletions(completions: [FuzzyCompletion]) {
        // Override all current completions.
        currentCompletions = completions
        quickOpenViewController.displayCompletions()
    }
    
    func getCompletion(at index: Int) -> FuzzyCompletion {
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

    weak var quickOpenCompletionController: QuickOpenCompletionController?
    weak var quickOpenDelegate: QuickOpenDelegate!
    var completionTableViewController: QuickOpenCompletionTableViewController!
    var completionTableView: QuickOpenTableView {
        return completionTableViewController.completionTableView
    }
    
    var completionSize: NSSize {
        return NSSize(width: self.view.frame.width, 
                      height: completionTableViewController.calculatedTableViewHeight + inputSearchField.frame.height)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        inputSearchField.delegate = self
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier {
            if identifier == "QuickOpenCompletionTableViewControllerSegue" {
                let controller = segue.destinationController as! QuickOpenCompletionTableViewController
                completionTableViewController = controller
                completionTableViewController.completionTableView.dataSource = self.quickOpenCompletionController
            }
        }
    }

    // MARK: Completion Management
    func displayCompletions() {
        self.completionTableView.reloadData()
        self.view.window?.setContentSize(completionSize)
    }

    func clearCompletions() {
        inputSearchField.stringValue = ""
        quickOpenCompletionController?.clearCompletions()
        self.view.window?.setContentSize(completionSize)
    }
    
    func selectCompletion(atIndex index: Int) {
        if let completionController = self.quickOpenCompletionController {
            let selectedCompletion = completionController.getCompletion(at: index)
            self.quickOpenDelegate?.didSelectQuickOpenCompletion(with: selectedCompletion)
        }
    }

    // Refreshes quick open completion on type.
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
            clearCompletions()
            quickOpenDelegate.closeQuickOpenCompletionPanel()
            return true
            
        // Up/Down
        case #selector(moveUp(_:)), #selector(moveDown(_:)):
            self.completionTableView.keyDown(with: NSApp.currentEvent!)
            return true
            
        // Return/Enter
        case #selector(insertNewline(_:)):
            let selectedCompletionIndex = self.completionTableView.selectedRow
            self.selectCompletion(atIndex: selectedCompletionIndex)
            return true
            
        default:
            return false
        }
    }
}

// MARK: QuickOpenDelegate
extension EditViewController {
    func showQuickOpenCompletionPanel() {
        editView.window?.beginSheet(quickOpenPanel, completionHandler: nil)
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
    
    func closeQuickOpenCompletionPanel() {
        // Cleanup on close or something
        editView.window?.endSheet(quickOpenPanel)
        print("quick open closed")
    }
}
