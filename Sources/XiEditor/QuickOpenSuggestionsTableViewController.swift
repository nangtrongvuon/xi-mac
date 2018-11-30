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

class QuickOpenSuggestionsTableViewController: NSViewController {

    @IBOutlet weak var suggestionsTableView: NSTableView!
    @IBOutlet var suggestionsScrollView: NSScrollView!

    override func viewDidLoad() {
        super.viewDidLoad()
        roundCompletionViewCorners()

        suggestionsTableView.wantsLayer = true
        suggestionsTableView.focusRingType = .none
        suggestionsTableView.dataSource = self
        suggestionsTableView.delegate = self
        suggestionsTableView.target = self

        suggestionsScrollView.setFrameSize(NSSize(width: suggestionsScrollView.frame.width, height: 100))
    }

    func roundCompletionViewCorners() {
        let scrollView = suggestionsTableView.enclosingScrollView!
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 7
        scrollView.contentView.wantsLayer = true
        scrollView.contentView.layer?.cornerRadius = 7
    }

    // Force table view to load all of its views on awake from nib.
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.view
    }
}

extension QuickOpenSuggestionsTableViewController: NSTableViewDelegate, NSTableViewDataSource {

    fileprivate enum CellIdentifiers {
        static let FilenameCell = "FilenameCellID"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return 1
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text = ""
        var cellIdentifier = ""

        if tableColumn == tableView.tableColumns[0] {
            text = "SomeQuickOpenSuggestion.swift"
            cellIdentifier = CellIdentifiers.FilenameCell
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? QuickOpenSuggestionCellView {
            cell.filenameTextField.stringValue = text
            return cell
        }
        return nil
    }
}
