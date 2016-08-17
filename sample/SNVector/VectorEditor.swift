//
//  VectorEditor.swift
//  SNVector
//
//  Created by satoshi on 8/16/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class VectorEditor: UIViewController {
    var elements = [SNPathElement]()
    let radius = 20.0 as CGFloat
    let baseTag = 100
    var indexDragging:Int?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let layerCurve = CAShapeLayer()
        
        layerCurve.path = SNPath.pathFrom(elements)
        layerCurve.lineWidth = 1
        layerCurve.fillColor = UIColor.clearColor().CGColor
        layerCurve.strokeColor = UIColor(red: 0, green: 0, blue: 1, alpha: 1.0).CGColor
        layerCurve.lineCap = "round"
        layerCurve.lineJoin = "round"
        self.view.layer.addSublayer(layerCurve)
        
        func addViewAt(pt:CGPoint, index:Int) {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2))
            view.backgroundColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.3)
            view.layer.cornerRadius = radius
            view.layer.masksToBounds = true
            view.tag = baseTag + index
            self.view.addSubview(view)
            view.center = pt
        }
        
        for (index, element) in elements.enumerate() {
            switch(element) {
            case let move as SNMove:
                addViewAt(move.pt, index:index)
            case let quad as SNQuadCurve:
                addViewAt(quad.cp, index:index)
                //addViewAt(quad.pt)
            default:
                break
            }
        }
        
        if let quad = elements.last as? SNQuadCurve {
            addViewAt(quad.pt, index:elements.count)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}


// MARK: UIResponder

extension VectorEditor {
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first {
            if let subview = touch.view where subview.tag >= baseTag {
                indexDragging = subview.tag - baseTag
            }
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let index = indexDragging,
           let touch = touches.first,
           let subview = view.viewWithTag(index + baseTag) {
            let pt = touch.locationInView(view)
            subview.center = pt
        }
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        indexDragging = nil
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        indexDragging = nil
    }
}
