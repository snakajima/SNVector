//
//  SNVectorEditor.swift
//  SNVector
//
//  Created by satoshi on 8/20/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

protocol SNVectorEditorProtocol: NSObjectProtocol {
    func pathWasUpdated(editor:SNVectorEditor)
}

class SNVectorEditor: UIViewController {
    @IBOutlet var viewMain:UIView!
    
    weak var delegate:SNVectorEditorProtocol?
    
    private let layerCurve = CAShapeLayer()
    private let layerPoly = CAShapeLayer()
    
    var elements = [SNPathElement]()
    private var nodes = [SNNodeView]()
    private var closed = false
    private var undoStack = [Undoable]()
    private var undoCursor = 0

    // Transient properties
    private var nodeTapped:SNNodeView? // for panTapped
    private var transformLast = CGAffineTransformIdentity // for pinch & pan
    private var locationLast = CGPoint.zero // pan
    
    var nodeTransform:CGAffineTransform {
        var xf = CGAffineTransformInvert(viewMain.transform)
        xf.tx = 0; xf.ty = 0
        return xf
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(SNVectorEditor.pinch))
        self.view.addGestureRecognizer(pinch)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(SNVectorEditor.pan))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        self.view.addGestureRecognizer(pan)
    }
    
    func extraInit(elements:[SNPathElement]) {
        self.elements = elements
        updateCurveFromElements()
        viewMain.layer.addSublayer(layerPoly)
        viewMain.layer.addSublayer(layerCurve)
        
        initializeNodes()
        updateUI()
    }
    
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
    
    private func createNode(corner:Bool, pt:CGPoint) -> SNNodeView {
        let node = SNNodeView()
        node.corner = corner
        node.center = pt
        prepareNode(node)
        return node
    }
    
    private func prepareNode(node:SNNodeView) {
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

        node.transform = nodeTransform
    }

    private func initializeNodes() {
        var elements = self.elements // making a copy
        if elements.last is SNCloseSubpath {
            closed = true
            elements.removeLast()
        }

        nodes.removeAll()
        
        var xf = nodeTransform

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
}

// MARK: Moving Nodes around
extension SNVectorEditor {
    func panNode(recognizer:UIPanGestureRecognizer) {
        guard let node = recognizer.view as? SNNodeView else {
            return
        }
        let pt = recognizer.locationInView(viewMain)
        switch(recognizer.state) {
        case .Began:
            node.lastCenter = node.center
            node.offset = pt.delta(node.center)
            UIMenuController.sharedMenuController().menuVisible = false
        case .Changed:
            let cp = pt.delta(node.offset)
            node.center = cp
            updateElements()
        case .Ended:
            let index = nodes.indexOf(node)!
            appendUndoable(MoveNode(index: index, ptOld: node.lastCenter, ptNew: node.center))
        default:
            break
        }
    }
}

// MARK: Debug
extension SNVectorEditor {
    func debug() {
        nodes.forEach { $0.removeFromSuperview() }
        initializeNodes()
    }
}

// MARK: Popup menu
extension SNVectorEditor {
    func doubleTapNode(recognizer:UITapGestureRecognizer) {
        if let node = recognizer.view as? SNNodeView, let index = nodes.indexOf(node) {
            node.corner = !node.corner
            appendUndoable(ToggleNode(index: index, corner: node.corner))
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
            
            var frame = node.bounds
            let offset = recognizer.locationInView(node)
            frame.origin = recognizer.locationInView(self.view).translate(-offset.x, y: -offset.y)
            mc.setTargetRect(frame, inView: self.view)
            
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

            appendUndoable(DeleteNode(index: index, pt: node.center, corner: node.corner))
            updateElements()
        }
    }

    func duplicateNode(menuController: UIMenuController) {
        if let node = nodeTapped, let index = nodes.indexOf(node) {
            let nodeCopy = createNode(node.corner, pt:node.center.translate(SNNodeView.radius * 2, y: 0))
            nodeCopy.transform = node.transform
            nodes.insert(nodeCopy, atIndex: index + 1)
            viewMain.insertSubview(nodeCopy, aboveSubview: node)
            
            appendUndoable(InsertNode(index: index + 1, pt: nodeCopy.center, corner: nodeCopy.corner))
            updateElements()
        }
    }
    
    func toggleNode(menuController: UIMenuController) {
        if let node = nodeTapped, let index = nodes.indexOf(node) {
            node.corner = !node.corner
            appendUndoable(ToggleNode(index: index, corner: node.corner))
            updateElements()
        }
    }

    func closePath(menuController: UIMenuController) {
        closed = true
        nodes.first!.corner = false
        nodes.last!.corner = false
        appendUndoable(ClosePath())
        updateElements()
    }

    func openPath(menuController: UIMenuController) {
        if let node = nodeTapped, let index = nodes.indexOf(node) {
            closed = false
            nodes = Array(0..<nodes.count).map {
                nodes[($0 + index) % nodes.count]
            }
            appendUndoable(OpenPath(index: index, cornerFirst: nodes.first!.corner, cornerLast: nodes.last!.corner))
            updateElements()
        }
    }
}

// MARK: Pinch & Zoom, Panning of main view
extension SNVectorEditor {
    func pinch(recognizer:UIPinchGestureRecognizer) {
        switch(recognizer.state) {
        case .Began:
            locationLast = recognizer.locationInView(view)
            transformLast = viewMain.transform
            UIMenuController.sharedMenuController().menuVisible = false
        case .Changed:
            //viewMain.transform = CGAffineTransformScale(transformLast, recognizer.scale, recognizer.scale)
            let delta = locationLast.delta(view.center)
            var xf = CGAffineTransformTranslate(transformLast, delta.x, delta.y)
            xf = CGAffineTransformScale(xf, recognizer.scale, recognizer.scale)
            viewMain.transform = CGAffineTransformTranslate(xf, -delta.x, -delta.y)
            let xfNode = nodeTransform
            nodes.forEach { $0.transform = xfNode }
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
            let a = viewMain.transform.a
            viewMain.transform = CGAffineTransformTranslate(transformLast, delta.x / a, delta.y / a)
        case .Ended:
            break
        default:
            viewMain.transform = transformLast
        }
    }
}

// MARK: Undo & Redo
extension SNVectorEditor {
    var undoable:Bool {
        return undoCursor > 0
    }
    var redoable:Bool {
        return undoCursor < undoStack.count
    }

    private func updateUI() {
        delegate?.pathWasUpdated(self)
    }
    
    private func appendUndoable(item:Undoable) {
        if undoCursor < undoStack.count {
            undoStack.removeLast(undoStack.count - undoCursor)
        }
        undoStack.append(item)
        undoCursor += 1
        assert(undoCursor == undoStack.count)
        
        updateUI()
    }

    func undo() {
        if undoable {
            undoCursor -= 1
            let item = undoStack[undoCursor]
            if let node = item.undo(&nodes, closed: &closed), let index = nodes.indexOf(node) {
                prepareNode(node)
                viewMain.insertSubview(node, atIndex: index)
            }

            updateElements()
            updateUI()
        }
    }
    
    func redo() {
        if redoable {
            let item = undoStack[undoCursor]
            undoCursor += 1
            if let node = item.redo(&nodes, closed: &closed), let index = nodes.indexOf(node) {
                prepareNode(node)
                viewMain.insertSubview(node, atIndex: index)
            }

            updateElements()
            updateUI()
        }
    }

    private struct MoveNode: Undoable {
        let index:Int
        let ptOld:CGPoint
        let ptNew:CGPoint
        func redo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            nodes[index].center = ptNew
            return nil
        }
        func undo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            nodes[index].center = ptOld
            return nil
        }
    }

    private struct ToggleNode: Undoable {
        let index:Int
        let corner:Bool
        func redo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            nodes[index].corner = corner
            return nil
        }
        func undo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            nodes[index].corner = !corner
            return nil
        }
    }

    private struct InsertNode: Undoable {
        let index:Int
        let pt:CGPoint
        let corner:Bool
        func redo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            let node = SNNodeView()
            node.corner = corner
            node.center = pt
            nodes.insert(node, atIndex: index)
            return node
        }
        
        func undo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            nodes[index].removeFromSuperview()
            nodes.removeAtIndex(index)
            return nil
        }
    }

    private struct ClosePath: Undoable {
        func redo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            closed = true
            nodes.first!.corner = false
            nodes.last!.corner = false
            return nil
        }
        
        func undo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            closed = false
            return nil
        }
    }

    private struct OpenPath: Undoable {
        let index:Int
        let cornerFirst:Bool
        let cornerLast:Bool
        func redo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            closed = false
            nodes = Array(0..<nodes.count).map {
                nodes[($0 + index) % nodes.count]
            }
            return nil
        }
        
        func undo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            closed = true
            nodes.first!.corner = cornerFirst
            nodes.last!.corner = cornerLast
            nodes = Array(0..<nodes.count).map {
                nodes[($0 + nodes.count - index) % nodes.count]
            }
            return nil
        }
    }

    private struct DeleteNode: Undoable {
        let index:Int
        let pt:CGPoint
        let corner:Bool
        func redo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            nodes[index].removeFromSuperview()
            nodes.removeAtIndex(index)
            return nil
        }
        
        func undo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView? {
            let node = SNNodeView()
            node.corner = corner
            node.center = pt
            nodes.insert(node, atIndex: index)
            return node
        }
    }

}

private protocol Undoable {
    func redo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView?
    func undo(inout nodes:[SNNodeView], inout closed:Bool) -> SNNodeView?
}

    