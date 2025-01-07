//
//  DragComponent.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

struct DragComponent: ECSComponent {
    var draggedObject: PlacedObjectEntity
    var initialPosition: SIMD3<Float>
    init(objectToDrag: PlacedObjectEntity) {
        draggedObject = objectToDrag
        initialPosition = objectToDrag.position
    }
}
