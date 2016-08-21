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
    var closed = false

    // Transient
    var offset = CGPoint.zero // for panNode
    var nodeTapped:SNNodeView? // for panTapped
    var transformLast = CGAffineTransformIdentity // for pinch & pan
    var locationLast = CGPoint.zero // pan

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
        var prev:SNNodeView?
        if closed {
            if !nodes.last!.corner {
                prev = nodes.last
            }
        } else {
            nodes.first!.corner = true
            nodes.last!.corner = true
        }

        elements.removeAll()
        for (i, node) in nodes.enumerate() {
            if i==0 {
                if closed && !node.corner {
                    elements.append(SNMove(pt: node.center))
                    prev = node
                } else {
                    elements.append(SNMove(pt: node.center))
                    prev = nil
                }
            } else if node.corner {
                if let prev = prev {
                    elements.append(SNQuadCurve(cp: prev.center, pt: node.center))
                } else {
                    elements.append(SNLine(pt: node.center))
                }
                prev = nil
                if closed && node == nodes.last, let first = nodes.first {
                    if first.corner {
                        elements.append(SNLine(pt: first.center))
                    } else {
                        //elements.append(SNQuadCurve(cp: node.center, pt: node.center.middle(first.center)))
                    }
                }
            } else {
                if let prev = prev {
                    elements.append(SNQuadCurve(cp: prev.center, pt: prev.center.middle(node.center)))
                } else {
                    // no need to add this case
                }
                prev = node
                if closed && node == nodes.last, let first = nodes.first {
                    if first.corner {
                        elements.append(SNQuadCurve(cp: node.center, pt: first.center))
                    } else {
                        elements.append(SNQuadCurve(cp: node.center, pt: node.center.middle(first.center)))
                    }
                }
            }
        }
    }
    
    func prepareNode(node:SNNodeView) {
        let panNode = UIPanGestureRecognizer(target: self, action: #selector(SNVectorEditor.panNode))
        panNode.minimumNumberOfTouches = 1
        panNode.maximumNumberOfTouches = 1
        node.addGestureRecognizer(panNode)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(SNVectorEditor.tapNode))
        node.addGestureRecognizer(tap)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(SNVectorEditor.pinch))
        view.addGestureRecognizer(pinch)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(SNVectorEditor.pan))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(pan)

        updateCurve()
        findCorners()
        viewMain.layer.addSublayer(layerPoly)
        viewMain.layer.addSublayer(layerCurve)
        
        func addNodeViewAt(pt:CGPoint, corner:Bool) {
            let node = SNNodeView()
            node.corner = corner
            viewMain.addSubview(node)
            node.center = pt
            nodes.append(node)
            prepareNode(node)
        }
        
        for (index, element) in elements.enumerate() {
            switch(element) {
            case let move as SNMove:
                addNodeViewAt(move.pt, corner:true)
            case let line as SNLine:
                addNodeViewAt(line.pt, corner:true)
            case let quad as SNQuadCurve:
                addNodeViewAt(quad.cp, corner:false)
                if corners[index] {
                    addNodeViewAt(quad.pt, corner:true)
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
            offset = pt.delta(subview.center)
            UIMenuController.sharedMenuController().menuVisible = false
        case .Changed:
            let cp = pt.delta(offset)
            subview.center = cp
            updateElements()
            updateCurve()
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
            if node == nodes.first || node == nodes.last {
                if closed {
                    menuItems.append(UIMenuItem(title: "Open", action: #selector(SNVectorEditor.closePath(_:))))
                } else {
                    menuItems.append(UIMenuItem(title: "Close", action: #selector(SNVectorEditor.closePath(_:))))
                }
            }
            if closed || node != nodes.first && node != nodes.last {
                menuItems.append(UIMenuItem(title: "Flip", action: #selector(SNVectorEditor.flipNode(_:))))
            }
            menuItems.append(UIMenuItem(title: "Duplicate", action: #selector(SNVectorEditor.duplicateNode(_:))))
            if elements.count > 1 {
                menuItems.append(UIMenuItem(title: "Delete", action: #selector(SNVectorEditor.deleteNode(_:))))
            }
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
        if let node = nodeTapped, let index = nodes.indexOf(node) {
            let nodeCopy = SNNodeView()
            nodeCopy.corner = node.corner
            let pt = node.center
            nodeCopy.center = CGPoint(x: pt.x + SNNodeView.radius * 2, y: pt.y)
            prepareNode(nodeCopy)
            nodes.insert(nodeCopy, atIndex: index + 1)
            viewMain.insertSubview(nodeCopy, aboveSubview: node)
            updateElements()
            updateCurve()
        }
    }
    
    func flipNode(menuController: UIMenuController) {
        print("Flip Node")
        if let node = nodeTapped {
            node.corner = !node.corner
            updateElements()
            updateCurve()
        }
    }

    func closePath(menuController: UIMenuController) {
        print("Close Path")
        closed = !closed
        updateElements()
        updateCurve()
    }

    func pinch(recognizer:UIPinchGestureRecognizer) {
        switch(recognizer.state) {
        case .Began:
            transformLast = viewMain.transform
            UIMenuController.sharedMenuController().menuVisible = false
        case .Changed:
            viewMain.transform = CGAffineTransformScale(transformLast, recognizer.scale, recognizer.scale)
            var xf = CGAffineTransformInvert(viewMain.transform)
            xf.tx = 0; xf.ty = 0
            nodes.forEach { $0.transform = xf }
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
            UIMenuController.sharedMenuController().menuVisible = false
        case .Changed:
            viewMain.transform = CGAffineTransformTranslate(transformLast, delta.x, delta.y)
        case .Ended:
            break
        default:
            viewMain.transform = transformLast
        }
    }
}
