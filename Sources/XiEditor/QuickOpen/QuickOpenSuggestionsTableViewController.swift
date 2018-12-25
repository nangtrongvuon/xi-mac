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

// MARK: - Utility Classes
class QuickOpenTableView: NSTableView {
    override var needsPanelToBecomeKey: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
}

class QuickOpenSuggestionCellView: NSTableCellView {
    @IBOutlet weak var filenameTextField: NSTextField!
}

// MARK: - Suggestions Table View Controller
class QuickOpenSuggestionsTableViewController: NSViewController {

    @IBOutlet weak var suggestionsTableView: QuickOpenTableView!
    @IBOutlet var suggestionsScrollView: NSScrollView!

    var testData = ["someFile.swift", "someOtherFile.swift", "thirdFile.swift"]
    let suggestionRowHeight = 30
    /// Small margin, enough to hide the scrollbar.
    let suggestionMargin = 3
    /// The maximum number of suggestions shown without scrolling.
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

    /// Force table view to load all of its views on awake from nib.
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.view
    }

    /// Resizes table view to fit suggestions.
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
