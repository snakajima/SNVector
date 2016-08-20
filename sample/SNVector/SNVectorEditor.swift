//
//  SNVectorEditor.swift
//  SNVector
//
//  Created by satoshi on 8/20/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class SNVectorEditor: UIViewController {
    @IBOutlet var viewMain:UIView!
    let layerCurve = CAShapeLayer()
    let layerPoly = CAShapeLayer()
    var elements = [SNPathElement]()
    var corners = [Bool]()
    var nodes = [SNNodeView]()
    let radius = 22.0 as CGFloat

    var offset = CGPoint.zero // transient for panNode

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

    override func viewDidLoad() {
        super.viewDidLoad()

/*
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(SNVectorEditor.pinch))
        view.addGestureRecognizer(pinch)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(SNVectorEditor.pan))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(pan)
*/
        updateCurve()
        findCorners()
        viewMain.layer.addSublayer(layerPoly)
        viewMain.layer.addSublayer(layerCurve)

        func addGestureRecognizers(subview:UIView) {
            let panNode = UIPanGestureRecognizer(target: self, action: #selector(VectorEditor.panNode))
            panNode.minimumNumberOfTouches = 1
            panNode.maximumNumberOfTouches = 1
            subview.addGestureRecognizer(panNode)
            
            //let tap = UITapGestureRecognizer(target: self, action: #selector(VectorEditor.tapNode))
            //subview.addGestureRecognizer(tap)
        }
        
        func addControlViewAt(pt:CGPoint, index:Int) {
            let subview = SNNodeView(frame: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2))
            subview.backgroundColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.3)
            subview.layer.cornerRadius = radius
            subview.layer.masksToBounds = true
            viewMain.insertSubview(subview, atIndex: 0)
            subview.center = pt
            nodes.append(subview)
            addGestureRecognizers(subview)
        }
    
        func addAnchorViewAt(pt:CGPoint, index:Int) {
            let subview = SNNodeView(frame: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2))
            subview.backgroundColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.3)
            viewMain.addSubview(subview)
            subview.center = pt
            nodes.append(subview)
            addGestureRecognizers(subview)
        }
        
        for (index, element) in elements.enumerate() {
            switch(element) {
            case let move as SNMove:
                addAnchorViewAt(move.pt, index:index)
            case let line as SNLine:
                addAnchorViewAt(line.pt, index:index)
            case let quad as SNQuadCurve:
                addControlViewAt(quad.cp, index:index)
                if corners[index] {
                    addAnchorViewAt(quad.pt, index: index)
                }
            default:
                print("unsupported 0")
            }
        }
    

    }

    func panNode(recognizer:UIPanGestureRecognizer) {
        guard let subview = recognizer.view else {
            return
        }
        let pt = recognizer.locationInView(viewMain)
        switch(recognizer.state) {
        case .Began:
            //indexDragging = subview.tag - baseTag
            offset = pt.delta(subview.center)
            UIMenuController.sharedMenuController().menuVisible = false
        case .Changed:
            let cp = pt.delta(offset)
            subview.center = cp
            /*
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
                        print("unsupported 1")
                    }
                } else {
                    index -= baseTag
                    assert(index < elements.count)
                    switch(elements[index]) {
                    case let quad as SNQuadCurve:
                        elements[index] = SNQuadCurve(cp: quad.cp, pt: cp)
                    case _ as SNMove:
                        elements[index] = SNMove(pt: cp)
                    case _ as SNLine:
                        elements[index] = SNLine(pt: cp)
                    default:
                        print("unsupported 2")
                    }
                }
                updateCurve()
            */
        case .Ended:
            //indexDragging = nil
            break
        default:
            break
        }
    }
}
