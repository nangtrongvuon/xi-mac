//
//  AutocompleteViewController.swift
//  XiEditor
//
//  Created by Dzũng Lê on 7/24/18.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Cocoa

protocol AutocompleteDelegate {
    func showCompletion()
    func selectCompletion(atIndex index: Int)
    func insertCompletion(atIndex index: Int)
    func closeCompletion()
}

class AutocompleteViewController: NSViewController {

    @IBOutlet weak var autocompleteTableView: AutocompleteTableView!

    var completionSuggestions = [CompletionItem]()
    var autocompleteDelegate: AutocompleteDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()

        roundCompletionViewCorners()

        autocompleteTableView.wantsLayer = true
        autocompleteTableView.focusRingType = .none
        autocompleteTableView.dataSource = self
        autocompleteTableView.delegate = self
        autocompleteTableView.doubleAction = #selector(selectCompletion)
        autocompleteTableView.target = self
    }

    func roundCompletionViewCorners() {
        let scrollView = autocompleteTableView.enclosingScrollView!

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

    @objc func selectCompletion() {
        let selectedRow = autocompleteTableView.selectedRow
        print("selected completion: \(completionSuggestions[selectedRow].label)")
        autocompleteDelegate.selectCompletion(atIndex: selectedRow)
    }
}

extension AutocompleteViewController: NSTableViewDelegate, NSTableViewDataSource {

    fileprivate enum CellIdentifiers {
        static let SuggestionCell = "SuggestionCellID"
        static let ReturnTypeCell = "ReturnTypeCellID"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return completionSuggestions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        var image: NSImage?
        var text = ""
        var cellIdentifier = ""

        // Main autocomplete column
        if tableColumn == tableView.tableColumns[0] {
            text = completionSuggestions[row].label
            cellIdentifier = CellIdentifiers.SuggestionCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = completionSuggestions[row].detail ?? ""
            cellIdentifier = CellIdentifiers.ReturnTypeCell
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? AutocompleteTableCellView {
            cell.imageView?.image = image ?? nil
            cell.suggestionTextField.stringValue = text
            return cell
        }
        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if let autocompleteTableView = notification.object as? AutocompleteTableView {
            //TODO: Send select_completions RPC to core
            let selectedRow = autocompleteTableView.selectedRow
            print("current highlighted row: \(selectedRow)")
        }
    }
}

extension EditViewController: AutocompleteDelegate {
    func selectCompletion(atIndex index: Int) {
        document.sendRpcAsync("completions_select", params: ["index": index])
    }

    func insertCompletion(atIndex index: Int) {
        document.sendRpcAsync("completions_insert", params: ["index": index])
    }

    func displayCompletions(forItems items: [[String : AnyObject]]) {

        autocompleteViewController.completionSuggestions.removeAll()
        for item in items {
            let label = item["label"] as! String
            let detail = item["detail"] as? String
            let documentation = item["documentation"] as? String

            let completionItem = CompletionItem(label: label, detail: detail, documentation: documentation)
            autocompleteViewController.completionSuggestions.append(completionItem)
        }
        autocompleteViewController.autocompleteTableView.reloadData()

        if let cursorPos = editView.cursorPos {
            autocompleteWindowController?.showCompletionWindow(forPosition: cursorPos)
        }
    }

    func showCompletion() {
        document.sendRpcAsync("completions_show", params: [])
    }

    func closeCompletion() {
        document.sendRpcAsync("completions_cancel", params: [])
        autocompleteWindowController?.closeCompletionWindow()
    }
}
