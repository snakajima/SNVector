//
//  VectorEditor.swift
//  SNVector
//
//  Created by satoshi on 8/16/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class VectorEditor: UIViewController {
    @IBOutlet var viewMain:UIView!
    let layerCurve = CAShapeLayer()
    let layerPoly = CAShapeLayer()
    var elements = [SNPathElement]()
    var corners = [Bool]()
    let radius = 20.0 as CGFloat
    let baseTag = 100
    var indexDragging:Int?
    var offset = CGPoint.zero
    var transformLast = CGAffineTransformIdentity
    var locationLast = CGPoint.zero

    private func updateCurve() {
        layerCurve.path = SNPath.pathFrom(elements)
        layerCurve.lineWidth = 3
        layerCurve.fillColor = UIColor.clearColor().CGColor
        layerCurve.strokeColor = UIColor(red: 0, green: 0, blue: 1, alpha: 1.0).CGColor
        layerCurve.lineCap = "round"
        layerCurve.lineJoin = "round"
        layerPoly.path = SNPath.polyPathFrom(elements)
        layerPoly.lineWidth = 1
        layerPoly.fillColor = UIColor.clearColor().CGColor
        layerPoly.strokeColor = UIColor(red: 0, green: 0.8, blue: 0, alpha: 1.0).CGColor
        layerPoly.lineCap = "round"
        layerPoly.lineJoin = "round"
    }
    
    private func findCorners() {
        corners.removeAll()
        for index in 0..<elements.count-1 {
            corners.append({
                if let quad = elements[index] as? SNQuadCurve,
                   let next = elements[index+1] as? SNQuadCurve where
                    quad.pt.distance2(quad.cp.middle(next.cp)) > 1 {
                    print("corner at", index)
                    return true
                }
                return false
            }())
        }
        corners.append(true)
        assert(corners.count == elements.count)
    }
    
    func pinch(recognizer:UIPinchGestureRecognizer) {
        switch(recognizer.state) {
        case .Began:
            transformLast = viewMain.transform
        case .Changed:
            viewMain.transform = CGAffineTransformScale(transformLast, recognizer.scale, recognizer.scale)
        case .Ended:
            break
        default:
            viewMain.transform = transformLast
        }
    }
    
    func pan(recognizer:UIPanGestureRecognizer) {
        if recognizer.numberOfTouches() != 2 {
            return
        }
        let pt = recognizer.locationInView(view)
        let delta = pt.delta(locationLast)
        switch(recognizer.state) {
        case .Began:
            transformLast = viewMain.transform
            locationLast = pt
        case .Changed:
            viewMain.transform = CGAffineTransformTranslate(transformLast, delta.x, delta.y)
        case .Ended:
            break
        default:
            viewMain.transform = transformLast
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(VectorEditor.pinch))
        view.addGestureRecognizer(pinch)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(VectorEditor.pan))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(pan)
        
        print("--")

        updateCurve()
        findCorners()
        viewMain.layer.addSublayer(layerPoly)
        viewMain.layer.addSublayer(layerCurve)
        
        func addControlViewAt(pt:CGPoint, index:Int) {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2))
            view.backgroundColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.3)
            view.layer.cornerRadius = radius
            view.layer.masksToBounds = true
            view.tag = baseTag + index
            viewMain.insertSubview(view, atIndex: 0)
            view.center = pt

            let panNode = UIPanGestureRecognizer(target: self, action: #selector(VectorEditor.panNode))
            panNode.minimumNumberOfTouches = 1
            panNode.maximumNumberOfTouches = 1
            view.addGestureRecognizer(panNode)
        }
        func addAnchorViewAt(pt:CGPoint, index:Int) {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2))
            view.backgroundColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.3)
            view.tag = baseTag + index + elements.count
            viewMain.addSubview(view)
            view.center = pt

            let panNode = UIPanGestureRecognizer(target: self, action: #selector(VectorEditor.panNode))
            panNode.minimumNumberOfTouches = 1
            panNode.maximumNumberOfTouches = 1
            view.addGestureRecognizer(panNode)
        }
        
        for (index, element) in elements.enumerate() {
            switch(element) {
            case let move as SNMove:
                addAnchorViewAt(move.pt, index:index)
            case let quad as SNQuadCurve:
                addControlViewAt(quad.cp, index:index)
                if corners[index] {
                    addAnchorViewAt(quad.pt, index: index)
                }
            default:
                break
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: panNode

extension VectorEditor {
    func panNode(recognizer:UIPanGestureRecognizer) {
        let pt = recognizer.locationInView(viewMain)
        switch(recognizer.state) {
        case .Began:
            if let subview = recognizer.view where subview.tag >= baseTag {
                indexDragging = subview.tag - baseTag
                print("began dragging", indexDragging!)
                let center = subview.center
                offset = CGPointMake(pt.x - center.x, pt.y - center.y)
            }
        case .Changed:
            if var index = indexDragging,
               let subview = view.viewWithTag(index + baseTag) {
                subview.center = CGPointMake(pt.x - offset.x, pt.y - offset.y)
                let cp = subview.center
                if index < elements.count {
                    switch(elements[index]) {
                    case let quad as SNQuadCurve:
                        if index > 0 && !corners[index-1], let prev = elements[index-1] as? SNQuadCurve {
                            elements[index-1] = SNQuadCurve(cp: prev.cp, pt: prev.cp.middle(cp))
                        }
                        if index+1 < elements.count && !corners[index], let next = elements[index+1] as? SNQuadCurve {
                            elements[index] = SNQuadCurve(cp: cp, pt: cp.middle(next.cp))
                        } else {
                            elements[index] = SNQuadCurve(cp: cp, pt: quad.pt)
                        }
                    default:
                        break
                    }
                } else {
                    index -= elements.count
                    assert(index < elements.count)
                    switch(elements[index]) {
                    case let quad as SNQuadCurve:
                        elements[index] = SNQuadCurve(cp: quad.cp, pt: cp)
                    case _ as SNMove:
                        elements[index] = SNMove(pt: cp)
                    default:
                        break
                    }
                }
                updateCurve()
            }
        case .Ended:
            indexDragging = nil
        default:
            break
        }
    }
}
