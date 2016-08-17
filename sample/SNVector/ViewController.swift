//
//  ViewController.swift
//  SNVector
//
//  Created by satoshi on 8/16/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var drawView:SNDrawView!
    var layers = [CALayer]()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        drawView.delegate = self
        drawView.shapeLayer.lineWidth = 5.0
        //drawView.builder.minSegment = 40.0
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let editor = segue.destinationViewController as? VectorEditor {
            editor.elements = drawView.builder.elements
        }
    }

}

extension ViewController : SNDrawViewDelegate {
    func didComplete(elements:[SNPathElement]) -> Bool {
        let layerCurve = CAShapeLayer()
        
        layerCurve.path = SNPath.pathFrom(elements)
        layerCurve.lineWidth = 10
        layerCurve.fillColor = UIColor.clearColor().CGColor
        layerCurve.strokeColor = UIColor(red: 0, green: 0, blue: 1, alpha: 0.3).CGColor
        layerCurve.lineCap = "round"
        layerCurve.lineJoin = "round"
        self.view.layer.addSublayer(layerCurve)
        layers.append(layerCurve)

        let layerLine = CAShapeLayer()
        layerLine.path = SNPath.polyPathFrom(elements)
        layerLine.lineWidth = 2
        layerLine.fillColor = UIColor.clearColor().CGColor
        layerLine.strokeColor = UIColor(red: 0, green: 0, blue: 0.5, alpha: 1.0).CGColor
        self.view.layer.addSublayer(layerLine)
        layers.append(layerLine)
        
        self.performSegueWithIdentifier("edit", sender: nil)

        return true
    }

    @IBAction func clear() {
        for layer in layers {
            layer.removeFromSuperlayer()
        }
        layers.removeAll()
    }
}



