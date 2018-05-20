//
//  StatusBar.swift
//  XiEditor
//
//  Created by Dzũng Lê on 19/05/2018.
//  Copyright © 2018 Raph Levien. All rights reserved.
//

import Foundation
import Cocoa

class StatusBar: NSView {

    enum StatusItemAlignment {
        case left
        case right
    }

    private let backgroundColor = NSColor(deviceWhite: 0.9, alpha: 1.0)
    private let statusBarHeight: CGFloat = 20

    override var isFlipped: Bool {
        return true;
    }

    func setup(_ editView: NSView) {

        self.translatesAutoresizingMaskIntoConstraints = false

        self.heightAnchor.constraint(equalToConstant: statusBarHeight).isActive = true
        self.widthAnchor.constraint(equalTo: editView.widthAnchor).isActive = true

        self.leadingAnchor.constraint(equalTo: editView.leadingAnchor).isActive = true
        self.trailingAnchor.constraint(equalTo: editView.trailingAnchor).isActive = true
        self.bottomAnchor.constraint(equalTo: editView.bottomAnchor).isActive = true

    }

    func addSBItem(_ item: NSTextField, alignment: StatusItemAlignment) {
        item.translatesAutoresizingMaskIntoConstraints = false
        item.textColor = NSColor.black

        self.addSubview(item)

        switch alignment {
        case .left:
            item.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true

        case .right:
            item.alignment = .right
            item.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true

        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath()
        backgroundColor.setFill()
        __NSRectFill(dirtyRect)
        path.move(to: CGPoint(x: dirtyRect.maxX, y: dirtyRect.minY))
        path.line(to: CGPoint(x: dirtyRect.minX, y: dirtyRect.minY))
    }
}
