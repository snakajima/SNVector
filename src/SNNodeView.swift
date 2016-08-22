//
//  SNNodeView.swift
//  SNVector
//
//  Created by satoshi on 8/20/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class SNNodeView: UIView {
    static let radius = 22.0 as CGFloat
    var corner = false {
        didSet {
            if corner {
                self.layer.cornerRadius = 0.0
            } else {
                self.layer.cornerRadius = SNNodeView.radius
            }
        }
    }
    // Transient properties
    var offset = CGPoint.zero // for panNode
    var lastCenter = CGPoint.zero
    
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: SNNodeView.radius * 2, height: SNNodeView.radius * 2))
        self.backgroundColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.3)
        self.layer.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)!
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
}
