//
//  SNVectorEditor.swift
//  SNVector
//
//  Created by satoshi on 8/20/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

protocol SNVectorEditorProtocol: NSObjectProtocol {
    func pathWasUpdated(_ editor:SNVectorEditor)
    func nodeColor(_ editor:SNVectorEditor) -> UIColor?
}

extension SNVectorEditorProtocol {
    func nodeColor(_ editor:SNVectorEditor) -> UIColor? {
        return nil
    }
}

class SNVectorEditor: UIViewController {
    @IBOutlet var viewMain:UIView!
    
    weak var delegate:SNVectorEditorProtocol?
    
    private let layerCurve:CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.lineWidth = 1
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.black.cgColor
        layer.lineCap = convertToCAShapeLayerLineCap("round")
        layer.lineJoin = convertToCAShapeLayerLineJoin("round")
        return layer
    }()
    private let layerPoly:CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.lineWidth = 1
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.2).cgColor
        layer.lineCap = convertToCAShapeLayerLineCap("round")
        layer.lineJoin = convertToCAShapeLayerLineJoin("round")
        return layer
    }()
    
    var elements = [SNPathElement]()
    fileprivate var nodes = [SNNodeView]()
    fileprivate var closed = false
    fileprivate var undoStack = [Undoable]()
    fileprivate var undoCursor = 0

    // Transient properties
    fileprivate var nodeTapped:SNNodeView? // for panTapped
    fileprivate var transformLast = CGAffineTransform.identity // for pinch & pan
    fileprivate var locationLast = CGPoint.zero // pan
    
    var nodeTransform:CGAffineTransform {
        var xf = viewMain.transform.inverted()
        xf.tx = 0; xf.ty = 0
        return xf
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewMain.layer.addSublayer(layerPoly)
        viewMain.layer.addSublayer(layerCurve)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(SNVectorEditor.pinch))
        self.view.addGestureRecognizer(pinch)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(SNVectorEditor.pan))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        self.view.addGestureRecognizer(pan)
    }
    
    func extraInit(_ elements:[SNPathElement]) {
        let path = SNPath.path(from: elements)
        let frame = path.boundingBoxOfPath
        let dx = viewMain.frame.size.width / 2 - (frame.origin.x + frame.size.width/2)
        let dy = viewMain.frame.size.height / 2 - (frame.origin.y + frame.size.height/2)
        self.elements = elements.map({ element -> SNPathElement in
            element.translatedElement(x: dx, y: dy)
        })
        
        updateCurveFromElements()
        initializeNodes()
        updateUI()
    }
    
    private func updateCurveFromElements() {
        layerCurve.path = SNPath.path(from: elements)
        layerPoly.path = SNPath.polyPath(from: elements)
    }
    
    fileprivate func updateElements() {
        let first = nodes.first!
        let last:SNNodeView?
        if closed {
            last = nodes.last
        } else {
            first.corner = true
            nodes.last!.corner = true
            last = nil
        }

        elements.removeAll()

        var prev:SNNodeView?
        for (i, node) in nodes.enumerated() {
            if i==0 {
                if let last = last, !node.corner {
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
                if node == last && first.corner {
                    elements.append(SNLine(pt: first.center))
                }
            } else {
                if let prev = prev {
                    elements.append(SNQuadCurve(cp: prev.center, pt: prev.center.middle(node.center)))
                }
                prev = node
                if node == last {
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
    
    fileprivate func createNode(_ corner:Bool, pt:CGPoint) -> SNNodeView {
        let node = SNNodeView()
        node.corner = corner
        node.center = pt
        prepareNode(node)
        return node
    }
    
    fileprivate func prepareNode(_ node:SNNodeView) {
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
        
        if let color = delegate?.nodeColor(self) {
            node.backgroundColor = color
            node.alpha = 0.3
        }
    }

    fileprivate func initializeNodes() {
        var elements = self.elements // making a copy
        if elements.last is SNCloseSubpath {
            closed = true
            elements.removeLast()
        }

        nodes.removeAll()
        
        var xf = nodeTransform

        func addNodeView(at pt:CGPoint, corner:Bool) {
            let node = createNode(corner, pt: pt)
            viewMain.addSubview(node)
            nodes.append(node)
        }
        
        for (index, element) in elements.enumerated() {
            switch(element) {
            case let move as SNMove where index==0:
                if closed, let next = elements[1] as? SNQuadCurve,
                   let last = elements.last as? SNQuadCurve,
                       last.pt.distance2(last.cp.middle(next.cp)) < 1 {
                    break
                }
                addNodeView(at:move.pt, corner:true)
            case _ as SNLine where closed && index + 1 == elements.count:
                break
            case let line as SNLine:
                addNodeView(at:line.pt, corner:true)
            case let quad as SNQuadCurve where closed && index + 1 == elements.count:
                addNodeView(at:quad.cp, corner:false)
            case let quad as SNQuadCurve:
                addNodeView(at:quad.cp, corner:false)
                if index + 1 < elements.count,
                   let next = elements[(index + 1) % elements.count] as? SNQuadCurve,
                       quad.pt.distance2(quad.cp.middle(next.cp)) < 1 {
                    break
                }
                addNodeView(at:quad.pt, corner:true)
            default:
                print("unsupported 0")
            }
        }
    }
}

// MARK: Moving Nodes around
extension SNVectorEditor {
    @objc func panNode(recognizer:UIPanGestureRecognizer) {
        guard let node = recognizer.view as? SNNodeView else {
            return
        }
        let pt = recognizer.location(in: viewMain)
        switch(recognizer.state) {
        case .began:
            node.lastCenter = node.center
            node.offset = pt.delta(node.center)
            UIMenuController.shared.isMenuVisible = false
        case .changed:
            let cp = pt.delta(node.offset)
            node.center = cp
            updateElements()
        case .ended:
            let index = nodes.index(of: node)!
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
    @objc func doubleTapNode(recognizer:UITapGestureRecognizer) {
        if let node = recognizer.view as? SNNodeView, let index = nodes.index(of: node) {
            node.corner = !node.corner
            appendUndoable(ToggleNode(index: index, corner: node.corner))
            updateElements()

            UIView.animate(withDuration: 0.2, animations: {
                //
            }, completion: { (_) in
                let mc = UIMenuController.shared
                mc.isMenuVisible = false
            })
        }
    }
    
    @objc func tapNode(recognizer:UITapGestureRecognizer) {
        if let node = recognizer.view as? SNNodeView {
            nodeTapped = node
            node.becomeFirstResponder()
            let mc = UIMenuController.shared
            
            var frame = node.bounds
            let offset = recognizer.location(in: node)
            frame.origin = recognizer.location(in: self.view).translate(x: -offset.x, y: -offset.y)
            mc.setTargetRect(frame, in: self.view)
            
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
            mc.isMenuVisible = true
        }
    }

    @objc func deleteNode(_ menuController: UIMenuController) {
        if let node = nodeTapped, let index = nodes.index(of: node) {
            node.removeFromSuperview()
            nodes.remove(at: index)

            appendUndoable(DeleteNode(index: index, pt: node.center, corner: node.corner))
            updateElements()
        }
    }

    @objc func duplicateNode(_ menuController: UIMenuController) {
        if let node = nodeTapped, let index = nodes.index(of: node) {
            let delta = CGPoint(x:SNNodeView.radius * 2, y:0).applying(nodeTransform)
            let nodeCopy = createNode(node.corner, pt:node.center.translate(x: delta.x, y: delta.y))
            nodeCopy.transform = node.transform
            nodes.insert(nodeCopy, at: index + 1)
            viewMain.insertSubview(nodeCopy, aboveSubview: node)
            
            appendUndoable(InsertNode(index: index + 1, pt: nodeCopy.center, corner: nodeCopy.corner))
            updateElements()
        }
    }
    
    @objc func toggleNode(_ menuController: UIMenuController) {
        if let node = nodeTapped, let index = nodes.index(of: node) {
            node.corner = !node.corner
            appendUndoable(ToggleNode(index: index, corner: node.corner))
            updateElements()
        }
    }

    @objc func closePath(_ menuController: UIMenuController) {
        closed = true
        nodes.first!.corner = false
        nodes.last!.corner = false
        appendUndoable(ClosePath())
        updateElements()
    }

    @objc func openPath(_ menuController: UIMenuController) {
        if let node = nodeTapped, let index = nodes.index(of: node) {
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
    @objc func pinch(recognizer:UIPinchGestureRecognizer) {
        if recognizer.numberOfTouches != 2 {
            return
        }
        let pt = recognizer.location(in: view)
        switch(recognizer.state) {
        case .began:
            locationLast = pt
            transformLast = viewMain.transform
            UIMenuController.shared.isMenuVisible = false
        case .changed:
            let offset = pt.delta(locationLast)
            let delta = locationLast.delta(view.center)
            var xf = transformLast.translatedBy(x: offset.x + delta.x, y: offset.y + delta.y)
            xf = xf.scaledBy(x: recognizer.scale, y: recognizer.scale)
            viewMain.transform = xf.translatedBy(x: -delta.x, y: -delta.y)
            let xfNode = nodeTransform
            nodes.forEach { $0.transform = xfNode }
        case .ended:
            break
        default:
            viewMain.transform = transformLast
        }
    }
    
    @objc func pan(recognizer:UIPanGestureRecognizer) {
        if recognizer.numberOfTouches != 2 {
            return
        }
        let pt = recognizer.location(in: view)
        switch(recognizer.state) {
        case .began:
            transformLast = viewMain.transform
            locationLast = pt
            UIMenuController.shared.isMenuVisible = false
        case .changed:
            let delta = pt.delta(locationLast)
            let a = viewMain.transform.a
            viewMain.transform = transformLast.translatedBy(x: delta.x / a, y: delta.y / a)
        case .ended:
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

    fileprivate func updateUI() {
        delegate?.pathWasUpdated(self)
    }
    
    fileprivate func appendUndoable(_ item:Undoable) {
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
            if let node = item.undo(&nodes, closed: &closed), let index = nodes.index(of: node) {
                prepareNode(node)
                viewMain.insertSubview(node, at: index)
            }

            updateElements()
            updateUI()
        }
    }
    
    func redo() {
        if redoable {
            let item = undoStack[undoCursor]
            undoCursor += 1
            if let node = item.redo(&nodes, closed: &closed), let index = nodes.index(of: node) {
                prepareNode(node)
                viewMain.insertSubview(node, at: index)
            }

            updateElements()
            updateUI()
        }
    }

    fileprivate struct MoveNode: Undoable {
        let index:Int
        let ptOld:CGPoint
        let ptNew:CGPoint
        func redo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            nodes[index].center = ptNew
            return nil
        }
        func undo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            nodes[index].center = ptOld
            return nil
        }
    }

    fileprivate struct ToggleNode: Undoable {
        let index:Int
        let corner:Bool
        func redo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            nodes[index].corner = corner
            return nil
        }
        func undo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            nodes[index].corner = !corner
            return nil
        }
    }

    fileprivate struct InsertNode: Undoable {
        let index:Int
        let pt:CGPoint
        let corner:Bool
        func redo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            let node = SNNodeView()
            node.corner = corner
            node.center = pt
            nodes.insert(node, at: index)
            return node
        }
        
        func undo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            nodes[index].removeFromSuperview()
            nodes.remove(at: index)
            return nil
        }
    }

    fileprivate struct ClosePath: Undoable {
        func redo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            closed = true
            nodes.first!.corner = false
            nodes.last!.corner = false
            return nil
        }
        
        func undo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            closed = false
            return nil
        }
    }

    fileprivate struct OpenPath: Undoable {
        let index:Int
        let cornerFirst:Bool
        let cornerLast:Bool
        func redo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            closed = false
            nodes = Array(0..<nodes.count).map {
                nodes[($0 + index) % nodes.count]
            }
            return nil
        }
        
        func undo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            closed = true
            nodes.first!.corner = cornerFirst
            nodes.last!.corner = cornerLast
            nodes = Array(0..<nodes.count).map {
                nodes[($0 + nodes.count - index) % nodes.count]
            }
            return nil
        }
    }

    fileprivate struct DeleteNode: Undoable {
        let index:Int
        let pt:CGPoint
        let corner:Bool
        func redo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            nodes[index].removeFromSuperview()
            nodes.remove(at: index)
            return nil
        }
        
        func undo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView? {
            let node = SNNodeView()
            node.corner = corner
            node.center = pt
            nodes.insert(node, at: index)
            return node
        }
    }

}

fileprivate protocol Undoable {
    func redo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView?
    func undo(_ nodes:inout [SNNodeView], closed:inout Bool) -> SNNodeView?
}

    

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToCAShapeLayerLineCap(_ input: String) -> CAShapeLayerLineCap {
	return CAShapeLayerLineCap(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToCAShapeLayerLineJoin(_ input: String) -> CAShapeLayerLineJoin {
	return CAShapeLayerLineJoin(rawValue: input)
}
