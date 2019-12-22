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

class QuickOpenSuggestionsWindowController: NSWindowController {

    override init(window: NSWindow?) {
        super.init(window: window)
        if let panel = window as? NSPanel {
            panel.styleMask = [.nonactivatingPanel]
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

    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
}
