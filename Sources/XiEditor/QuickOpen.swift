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
    override var acceptsFirstResponder: Bool { return true }
}

class QuickOpenSuggestionCellView: NSTableCellView {
    @IBOutlet weak var filenameTextField: NSTextField!
}

// MARK: Quick Open Window Handling
class QuickOpenPanel: NSPanel {
    // Required to receive keyboard input and events.
    override var canBecomeKey: Bool {
        return true
    }
}

class QuickOpenSuggestionsWindowController: NSWindowController {

    override init(window: NSWindow?) {
        super.init(window: window)
        if let panel = window as? NSPanel {
            panel.styleMask = [.nonactivatingPanel, .borderless]
            panel.isOpaque = false
            panel.level = .floating
            panel.hidesOnDeactivate = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.backgroundColor = .clear
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Suggestions Table View Controller
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

        suggestionsTableView.wantsLayer = true
        suggestionsTableView.focusRingType = .none
        suggestionsTableView.dataSource = self
        suggestionsTableView.delegate = self
        suggestionsTableView.target = self

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
        // Attachs the suggestion table view to the top left corner of the search field.
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
        suggestionWindowController.window!.close()
    }

    // Attaches the suggestion table view to the search field.
    override func controlTextDidBeginEditing(_ obj: Notification) {
        showSuggestionsForSearchField()
    }

    // MARK: - Handle panel commands
    // Closes panel when clicking outside of it.
    override func mouseDown(with event: NSEvent) {
        clearSuggestionsFromSearchField()
        quickOpenDelegate.closeQuickOpenSuggestions()
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
            quickOpenDelegate.selectedQuickOpenSuggestion(atIndex: self.suggestionsTableView.selectedRow)
            return true
        default:
            return false
        }
    }
}

extension EditViewController {
    // QuickOpenDelegate
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
