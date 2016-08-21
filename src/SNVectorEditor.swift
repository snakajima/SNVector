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
    var nodes = [SNNodeView]()
    var closed = false

    // Transient properties
    var offset = CGPoint.zero // for panNode
    var nodeTapped:SNNodeView? // for panTapped
    var transformLast = CGAffineTransformIdentity // for pinch & pan
    var locationLast = CGPoint.zero // pan

    private func updateCurveFromElements() {
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
    
    private func updateElements() {
        var last:SNNodeView?
        var prev:SNNodeView?
        if closed {
            last = nodes.last
        } else {
            nodes.first!.corner = true
            nodes.last!.corner = true
        }

        elements.removeAll()
        for (i, node) in nodes.enumerate() {
            if i==0 {
                if let last = last where !node.corner {
                    if !last.corner {
                        elements.append(SNMove(pt: last.center.middle(node.center)))
                    } else {
                        elements.append(SNMove(pt: last.center))
                    }
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
                    }
                }
            } else {
                if let prev = prev {
                    elements.append(SNQuadCurve(cp: prev.center, pt: prev.center.middle(node.center)))
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
        
        if closed {
            elements.append(SNCloseSubpath())
        }
        
        updateCurveFromElements()
    }
    
    func createNode(corner:Bool, pt:CGPoint) -> SNNodeView {
        let node = SNNodeView()
        node.corner = corner
        node.center = pt
        
        let panNode = UIPanGestureRecognizer(target: self, action: #selector(SNVectorEditor.panNode))
        panNode.minimumNumberOfTouches = 1
        panNode.maximumNumberOfTouches = 1
        node.addGestureRecognizer(panNode)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(SNVectorEditor.tapNode))
        tap.numberOfTapsRequired = 1
        node.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(SNVectorEditor.doubleTapNode))
        doubleTap.numberOfTapsRequired = 2
        node.addGestureRecognizer(doubleTap)
        return node
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(SNVectorEditor.pinch))
        view.addGestureRecognizer(pinch)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(SNVectorEditor.pan))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(pan)

        updateCurveFromElements()
        viewMain.layer.addSublayer(layerPoly)
        viewMain.layer.addSublayer(layerCurve)
        
        initializeNodes()
    }
    
    private func initializeNodes() {
        var elements = self.elements // making a copy
        if elements.last is SNCloseSubpath {
            closed = true
            elements.removeLast()
        }

        nodes.removeAll()
        
        func addNodeViewAt(pt:CGPoint, corner:Bool) {
            let node = createNode(corner, pt: pt)
            viewMain.addSubview(node)
            nodes.append(node)
        }
        
        for (index, element) in elements.enumerate() {
            switch(element) {
            case let move as SNMove where index==0:
                if closed, let next = elements[1] as? SNQuadCurve,
                   let last = elements.last as? SNQuadCurve
                         where last.pt.distance2(last.cp.middle(next.cp)) < 1 {
                    break
                }
                addNodeViewAt(move.pt, corner:true)
            case _ as SNLine where closed && index + 1 == elements.count:
                break
            case let line as SNLine:
                addNodeViewAt(line.pt, corner:true)
            case let quad as SNQuadCurve where closed && index + 1 == elements.count:
                addNodeViewAt(quad.cp, corner:false)
            case let quad as SNQuadCurve:
                addNodeViewAt(quad.cp, corner:false)
                if index + 1 < elements.count,
                   let next = elements[(index + 1) % elements.count] as? SNQuadCurve
                        where quad.pt.distance2(quad.cp.middle(next.cp)) < 1 {
                    break
                }
                addNodeViewAt(quad.pt, corner:true)
            default:
                print("unsupported 0")
            }
        }
    }

    func panNode(recognizer:UIPanGestureRecognizer) {
        guard let subview = recognizer.view as? SNNodeView else {
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
        case .Ended:
            print("panNode ended", nodes.indexOf(subview))
        default:
            break
        }
    }

    func doubleTapNode(recognizer:UITapGestureRecognizer) {
        if let node = recognizer.view as? SNNodeView {
            node.corner = !node.corner
            updateElements()
            UIView.animateWithDuration(0.2, animations: {
                //
            }, completion: { (_) in
                let mc = UIMenuController.sharedMenuController()
                mc.menuVisible = false
            })
        }
    }
    
    func tapNode(recognizer:UITapGestureRecognizer) {
        if let node = recognizer.view as? SNNodeView {
            nodeTapped = node
            node.becomeFirstResponder()
            let mc = UIMenuController.sharedMenuController()
            
            var frame = node.frame
            let offset = recognizer.locationInView(node)
            frame.origin = recognizer.locationInView(self.view).translate(-offset.x, y: -offset.y)
            mc.setTargetRect(frame, inView: view)
            
            var menuItems = [UIMenuItem]()
            if !closed && (node == nodes.first || node == nodes.last) {
                menuItems.append(UIMenuItem(title: "Close", action: #selector(SNVectorEditor.closePath(_:))))
            } else if closed {
                menuItems.append(UIMenuItem(title: "Open", action: #selector(SNVectorEditor.openPath(_:))))
            }
            if closed || node != nodes.first && node != nodes.last {
                menuItems.append(UIMenuItem(title: "Toggle", action: #selector(SNVectorEditor.toggleNode(_:))))
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
        if let node = nodeTapped, let index = nodes.indexOf(node) {
            node.removeFromSuperview()
            nodes.removeAtIndex(index)
            updateElements()
        }
    }

    func duplicateNode(menuController: UIMenuController) {
        if let node = nodeTapped, let index = nodes.indexOf(node) {
            let nodeCopy = createNode(node.corner, pt:node.center.translate(SNNodeView.radius * 2, y: 0))
            nodeCopy.transform = node.transform
            nodes.insert(nodeCopy, atIndex: index + 1)
            viewMain.insertSubview(nodeCopy, aboveSubview: node)
            updateElements()
        }
    }
    
    func toggleNode(menuController: UIMenuController) {
        if let node = nodeTapped {
            node.corner = !node.corner
            updateElements()
        }
    }

    func closePath(menuController: UIMenuController) {
        closed = true
        nodes.first!.corner = false
        nodes.last!.corner = false
        updateElements()
    }

    func openPath(menuController: UIMenuController) {
        if let node = nodeTapped, let index = nodes.indexOf(node) {
            closed = false
            nodes = Array(0..<nodes.count).map {
                nodes[($0 + index) % nodes.count]
            }
            updateElements()
        }
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
        switch(recognizer.state) {
        case .Began:
            transformLast = viewMain.transform
            locationLast = pt
            UIMenuController.sharedMenuController().menuVisible = false
        case .Changed:
            let delta = pt.delta(locationLast)
            viewMain.transform = CGAffineTransformTranslate(transformLast, delta.x, delta.y)
        case .Ended:
            break
        default:
            viewMain.transform = transformLast
        }
    }
    
    @IBAction func debug() {
        nodes.forEach { $0.removeFromSuperview() }
        initializeNodes()
    }
}
