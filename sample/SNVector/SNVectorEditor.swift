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
    var nodeTapped:SNNodeView? // transient for panTapped

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
    
    private func updateElements() {
        elements.removeAll()
        var prev:SNNodeView?
        for (i, node) in nodes.enumerate() {
            if i==0 {
                elements.append(SNMove(pt: node.center))
            } else if node.corner {
                if let prev = prev {
                    elements.append(SNQuadCurve(cp: prev.center, pt: node.center))
                } else {
                    elements.append(SNLine(pt: node.center))
                }
                prev = nil
            } else {
                if let prev = prev {
                    elements.append(SNQuadCurve(cp: prev.center, pt: prev.center.middle(node.center)))
                } else {
                    // skip
                }
                prev = node
            }
        }
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
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(VectorEditor.tapNode))
            subview.addGestureRecognizer(tap)
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
            subview.corner = true
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
            updateElements()
            updateCurve()
        case .Ended:
            //indexDragging = nil
            break
        default:
            break
        }
    }
    
    func tapNode(recognizer:UITapGestureRecognizer) {
        if let node = recognizer.view as? SNNodeView {
            nodeTapped = node
            node.becomeFirstResponder()
            let mc = UIMenuController.sharedMenuController()
            var frame = CGRectApplyAffineTransform(node.frame, viewMain.transform)
            frame.origin.y += viewMain.frame.origin.y
            mc.setTargetRect(frame, inView: view)
            var menuItems = [UIMenuItem]()
            if elements.count > 1 {
                menuItems.append(UIMenuItem(title: "Delete", action: #selector(VectorEditor.deleteNode(_:))))
            }
            menuItems.append(UIMenuItem(title: "Duplicate", action: #selector(VectorEditor.duplicateNode(_:))))
            mc.menuItems = menuItems
            mc.menuVisible = true
        }
    }

    func deleteNode(menuController: UIMenuController) {
        print("Delete Node")
        if let node = nodeTapped, let index = nodes.indexOf(node) {
            node.removeFromSuperview()
            nodes.removeAtIndex(index)
            updateElements()
            updateCurve()
        }
    }

    func duplicateNode(menuController: UIMenuController) {
        print("Duplicate Node")
    }
    
    func flipNode(menuController: UIMenuController) {
        print("Flip Node")
    }
}
