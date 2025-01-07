//
//  PlacementComponent.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//
import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

@Observable
class PlacementComponent: ECSComponent {
    var selectedObject: PlaceableObjectEntity? = nil
    var highlightedObject: PlacedObjectEntity? = nil
    var userDraggedAnObject = false
    var planeToProjectOnFound = false
    var activeCollisions = 0
    var dragInProgress = false
    var userPlacedAnObject = false
    var deviceAnchorPresent = false
    var planeAnchorsPresent = false
    
    var objectToPlace: PlaceableObjectEntity? {
        isPlacementPossible ? selectedObject : nil
    }
    var collisionDetected: Bool { activeCollisions > 0 }
    
    var shouldShowPreview: Bool {
        deviceAnchorPresent && planeAnchorsPresent && !dragInProgress && highlightedObject == nil
    }

    var isPlacementPossible: Bool {
        selectedObject != nil && shouldShowPreview && planeToProjectOnFound && !collisionDetected && !dragInProgress
    }
}
