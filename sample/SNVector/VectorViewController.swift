//
//  VectorViewController.swift
//  SNVector
//
//  Created by satoshi on 8/22/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class VectorViewController: UIViewController {
    var elements = [SNPathElement]()
    var editor = SNVectorEditor()

    @IBOutlet var viewMain:UIView!
    @IBOutlet var btnUndo:UIBarButtonItem!
    @IBOutlet var btnRedo:UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        viewMain.addSubview(editor.view)
        editor.extraInit(elements)
    }

    @IBAction func undo() {
        print("undo")
    }
    
    @IBAction func redo() {
        print("redo")
    }

    @IBAction func debug() {
    }
}
