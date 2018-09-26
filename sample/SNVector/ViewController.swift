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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let editor = segue.destination as? VectorViewController {
            editor.elements = drawView.builder.elements
        }
    }

}

extension ViewController : SNDrawViewDelegate {
    func didComplete(_ elements:[SNPathElement]) -> Bool {
        let layerCurve = CAShapeLayer()
        
        layerCurve.path = SNPath.path(from: elements)
        layerCurve.lineWidth = 10
        layerCurve.fillColor = UIColor.clear.cgColor
        layerCurve.strokeColor = UIColor(red: 0, green: 0, blue: 1, alpha: 0.3).cgColor
        layerCurve.lineCap = convertToCAShapeLayerLineCap("round")
        layerCurve.lineJoin = convertToCAShapeLayerLineJoin("round")
        self.view.layer.addSublayer(layerCurve)
        layers.append(layerCurve)

        let layerLine = CAShapeLayer()
        layerLine.path = SNPath.polyPath(from: elements)
        layerLine.lineWidth = 2
        layerLine.fillColor = UIColor.clear.cgColor
        layerLine.strokeColor = UIColor(red: 0, green: 0, blue: 0.5, alpha: 1.0).cgColor
        self.view.layer.addSublayer(layerLine)
        layers.append(layerLine)
        
        self.performSegue(withIdentifier: "edit", sender: nil)

        return true
    }

    @IBAction func clear() {
        for layer in layers {
            layer.removeFromSuperlayer()
        }
        layers.removeAll()
    }
}




// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToCAShapeLayerLineCap(_ input: String) -> CAShapeLayerLineCap {
	return CAShapeLayerLineCap(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToCAShapeLayerLineJoin(_ input: String) -> CAShapeLayerLineJoin {
	return CAShapeLayerLineJoin(rawValue: input)
}
