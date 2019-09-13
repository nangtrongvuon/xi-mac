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

// MARK: - Quick Open Window Handling
class QuickOpenPanel: NSPanel {
    var quickOpenViewController: QuickOpenViewController? {
        return self.contentViewController as? QuickOpenViewController
    }

    // Required to receive keyboard input and events.
    override var canBecomeKey: Bool {
        return true
    }

    // Closes quick open panel immediately when focus is lost.
    override func resignKey() {
        // Checking for panel visibility avoids double calling the cleanup methods,
        // since closing the panel seems to call `resignKey` again.
        #if DEBUG
        if self.isVisible {
            quickOpenViewController?.clearCompletions()
//            quickOpenViewController?.delegate.closeQuickOpenCompletionPanel()
        }
        #endif
    }
}

// MARK: - Quick Open Completions Table View Controller
class QuickOpenCompletionTableViewController: NSViewController {

    @IBOutlet var completionTableView: QuickOpenTableView!
    @IBOutlet var completionScrollView: NSScrollView!
    
    weak var quickOpenViewController: QuickOpenViewController?
    var quickOpenCompletionController: QuickOpenCompletionController {
        return self.completionTableView.dataSource as! QuickOpenCompletionController
    }

    /// The current height of the completion table view.
    /// This can go up to the `maximumCompletionTableViewHeight` defined below.
    var calculatedTableViewHeight: CGFloat {
        var calculatedHeight = CGFloat(quickOpenCompletionController.completionsCount) * completionRowHeight
        if calculatedHeight >= maximumCompletionTableViewHeight {
            calculatedHeight = maximumCompletionTableViewHeight
        }
        return calculatedHeight    
    }
    
    /// Height for each row in the completion table view.
    let completionRowHeight: CGFloat = 60
    /// The maximum number of completions shown without scrolling.
    /// Currently capped at 6, which is similar to other editors.
    let maximumCompletions = 6

    /// The tallest height that the completion can be.
    var maximumCompletionTableViewHeight: CGFloat {
        return CGFloat(maximumCompletions) * completionRowHeight
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        self.view.wantsLayer = true
        self.view.layer?.cornerRadius = 6 // 6 is considered to be the native corner radius.
    }

    func setupTableView() {
        self.completionTableView.delegate = self
        self.completionTableView.target = self
    }

    // Doing this forces `viewDidLoad` to call, which initializes all necessary views. 
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
            let query = quickOpenCompletionController.currentQuery
            let completion = quickOpenCompletionController.getCompletion(at: row)
            rowView.configure(query: query, completion: completion)
            return rowView    
        } else {
            return nil    
        }
    }
}

// MARK: - Quick Open Completion Manager
/// Handles quick open completions data and states.
class QuickOpenCompletionController: NSObject, NSTableViewDataSource {
    weak var delegate: QuickOpenCompletionDelegate?
    // The root path where quick open query matches originate from.
    private var root: String = ""
    private var currentCompletions = [FuzzyResult]()
    // This count is exposed for layout purposes.
    var completionsCount: Int { return currentCompletions.count }
    var currentQuery: String = ""

    func setQuickOpenRoot(to root: String) {
        self.root = root
    }
    
    /// Clear all completions.
    func clearCompletions() {
        currentCompletions.removeAll()
    }

    /// Parse received completions from core.
    func updateCompletions(completions: [FuzzyResult]) {
        // Override all current completions.
        currentCompletions = completions
        // Tells our view controller the list of completions has changed.
        delegate?.completionsChanged()
    }
    
    func getCompletion(at index: Int) -> FuzzyResult {
        return currentCompletions[index]
    }

    // Returns a full URL for a given completion.
    func getCompletionURL(at index: Int) -> URL {
        let rootPath = URL(fileURLWithPath: root)
        return rootPath.appendingPathComponent(currentCompletions[index].path)
    }
    
    // MARK: NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return completionsCount
    }
}

// MARK: - Quick Open View Controller
class QuickOpenViewController: NSViewController, NSSearchFieldDelegate {
    @IBOutlet weak var inputSearchField: NSSearchField!

    weak var delegate: QuickOpenViewDelegate!
    var completionController: QuickOpenCompletionController!
    var completionTableViewController: QuickOpenCompletionTableViewController!
    var completionTableView: QuickOpenTableView {
        return completionTableViewController.completionTableView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        inputSearchField.delegate = self
        self.completionController = QuickOpenCompletionController()
        self.completionController.delegate = self
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier {
            if identifier == "QuickOpenCompletionTableViewControllerSegue" {
                let controller = segue.destinationController as! QuickOpenCompletionTableViewController
                completionTableViewController = controller
                completionTableViewController.completionTableView.dataSource = self.completionController
            }
        }
    }

    // Sizes the window appropriately to the number of completions received.
    func resizeCompletionWindowToFit() {
        let fittingHeight = completionTableViewController.calculatedTableViewHeight + inputSearchField.frame.height
        let newCompletionWindowSize = NSSize(width: self.view.frame.width,
                          height: fittingHeight)
        self.view.window?.setContentSize(newCompletionWindowSize)
    }

    // MARK: Completion Management
    func displayNewCompletions() {
        self.completionTableView.reloadData()
        resizeCompletionWindowToFit()
    }

    func clearCompletions() {
        inputSearchField.stringValue = ""
        completionController.clearCompletions()
        resizeCompletionWindowToFit()
    }
    
    func selectCompletion(atIndex index: Int) {
        if let completionController = self.completionController {
            let completionPath = completionController.getCompletionURL(at: index)
            self.delegate?.didSelectQuickOpenCompletion(with: completionPath)
        }
    }

    // Refreshes quick open completion on type.
    func controlTextDidChange(_ obj: Notification) {
        let query = self.inputSearchField.stringValue
        completionController.currentQuery = query
        delegate.sendQuickOpenRequest(query: query)
    }

    // Overrides keyboard commands when the quick open panel is currently showing.
    // Not very elegant, but it does the job.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
            
        // ESC
        case #selector(cancelOperation(_:)):
            clearCompletions()
            delegate.closeQuickOpenCompletionPanel()
            return true
            
        // Up/Down
        case #selector(moveUp(_:)), #selector(moveDown(_:)):
            self.completionTableView.keyDown(with: NSApp.currentEvent!)
            return true
            
        // Return/Enter
        case #selector(insertNewline(_:)):
            let selectedRow = self.completionTableView.selectedRow
            // Don't allow choosing a completion if no row is selected.
            if selectedRow >= 0 {
                self.selectCompletion(atIndex: selectedRow)
                return true    
            } else {
                return false
            }
            
        default:
            return false
        }
    }
}

extension QuickOpenViewController: QuickOpenCompletionDelegate {
    func completionsChanged() {
        self.displayNewCompletions()
    }
}

// MARK: - Protocols and delegate handling
protocol QuickOpenCompletionDelegate: class {
    func completionsChanged()
}

protocol QuickOpenViewDelegate: class {
    func showQuickOpenCompletionPanel()
    func sendQuickOpenRequest(query: String)
    func didSelectQuickOpenCompletion(with completionPath: URL)
    func closeQuickOpenCompletionPanel()
}

extension EditViewController {
    func showQuickOpenCompletionPanel() {
        editView.window?.beginSheet(quickOpenPanel, completionHandler: nil)
    }
    
    func sendQuickOpenRequest(query: String) {
        xiView.sendQuickOpenRequest(query: query)
    }

    func didSelectQuickOpenCompletion(with completionPath: URL) {
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

// MARK: - Utility Classes
class QuickOpenTableView: NSTableView {
    override var needsPanelToBecomeKey: Bool { return true }
    override var acceptsFirstResponder: Bool { return false }
    override var isFlipped: Bool { return true }
}

// We subclass this just to disable smooth scroll in the table view.
class QuickOpenClipView: NSClipView {
    override func scroll(to newOrigin: NSPoint) {
        super.setBoundsOrigin(newOrigin)
    }
}

class QuickOpenCompletionRowView: NSTableRowView {
    @IBOutlet weak var fileNameLabel: NSTextField!
    @IBOutlet weak var fullPathLabel: NSTextField!

    /// Keeps the focused color on our table view rows, since we don't actually focus on it.
    override var isEmphasized: Bool {
        get { return true }
        // Does nothing, just here so we can override the getter
        set { }
    }

    /// Allows us to get some custom highlighting in.
    override func drawSelection(in dirtyRect: NSRect) {
        super.drawSelection(in: dirtyRect)

        NSColor.alternateSelectedControlColor.set()
        let rect = NSRect(x: 0, y: bounds.height - 2, width: bounds.width, height: bounds.height)
        let path = NSBezierPath(rect: rect)
        path.fill()
    }

    /// Configures this view with data from a completion.
    func configure(query: String, completion: FuzzyResult) {
        let fullPath = completion.path
        let processedCompletionName = highlightMatchingCharacters(with: query, in: completion)
        self.fileNameLabel.attributedStringValue = processedCompletionName
        self.fullPathLabel.stringValue = fullPath
    }

    /// Highlight matching quick open characters as they are typed.
    /// Tries to be UTF-8 safe.
    func highlightMatchingCharacters(with query: String, in result: FuzzyResult) -> NSAttributedString {
        let fileURL = URL(fileURLWithPath: result.path)
        let fileName = fileURL.lastPathComponent
        let resultAttributedString = NSMutableAttributedString(string: fileName)
        let highlightAttributes = [NSAttributedString.Key.font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .bold)]
        for index in result.match_indices {
            let highlightRange = NSMakeRange(index, 1)
            print("Highlight range: \(highlightRange)")
            resultAttributedString.addAttributes(highlightAttributes, range: highlightRange)
        }
        return resultAttributedString
    }
}
