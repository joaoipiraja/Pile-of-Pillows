//
//  PlacementSystem.swift
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
final class PlacementSystem: ECSSystem {
    private let worldTracking = WorldTrackingProvider()
    private let planeDetection = PlaneDetectionProvider()
    let rootEntity: Entity
    let planeAnchorSystem: PlaneAnchorSystem
    let persistenceSystem: PersistenceSystem
    var appComponent: AppComponent? = nil {
        didSet {
            persistenceSystem.placeableObjectsByFileName = appComponent?.placeableObjectsByFileName ?? [:]
        }
    }
    var placementComponent = PlacementComponent()
    private var currentDrag: DragComponent? = nil {
        didSet {
            placementComponent.dragInProgress = currentDrag != nil
        }
    }
    private let deviceLocation: Entity
    private let raycastOrigin: Entity
    private let placementLocation: Entity
    private weak var placementTooltip: Entity? = nil
    weak var dragTooltip: Entity? = nil
    weak var deleteButton: Entity? = nil
    
    static private let placedObjectsOffsetOnPlanes: Float = 0.01
    static private let snapToPlaneDistanceForDraggedObjects: Float = 0.04
    
    @MainActor
    init() {
        let entity = Entity()
        self.rootEntity = entity
        self.planeAnchorSystem = PlaneAnchorSystem(rootEntity: entity)
        self.persistenceSystem = PersistenceSystem(worldTracking: worldTracking, rootEntity: entity)
        placementLocation = Entity()
        deviceLocation = Entity()
        raycastOrigin = Entity()
        rootEntity.addChild(placementLocation)
        deviceLocation.addChild(raycastOrigin)
        let raycastDownwardAngle = 15.0 * (Float.pi / 180)
        raycastOrigin.orientation = simd_quatf(angle: -raycastDownwardAngle, axis: [1.0, 0.0, 0.0])
    }
    
    func saveWorldAnchorsObjectsMapToDisk() {
        persistenceSystem.saveWorldAnchorsObjectsMapToDisk()
    }
    
    @MainActor
    func addPlacementTooltip(_ tooltip: Entity) {
        placementTooltip = tooltip
        placementLocation.addChild(tooltip)
        tooltip.position = [0.0, 0.05, 0.1]
    }

    @MainActor
    func removeHighlightedObject() async {
        if let highlightedObject = placementComponent.highlightedObject {
            await persistenceSystem.removeObject(highlightedObject)
        }
    }
    
    @MainActor
    func runARKitSession() async {
        do {
            try await appComponent?.arkitSession.run([worldTracking, planeDetection])
        } catch {}
        
        if let firstFileName = appComponent?.modelDescriptors.first?.fileName,
           let object = appComponent?.placeableObjectsByFileName[firstFileName] {
            select(object)
        }
    }

    @MainActor
    func collisionBegan(_ event: CollisionEvents.Began) {
        guard let selectedObject = placementComponent.selectedObject else { return }
        guard selectedObject.matchesCollisionEvent(event: event) else { return }
        placementComponent.activeCollisions += 1
    }
    
    @MainActor
    func collisionEnded(_ event: CollisionEvents.Ended) {
        guard let selectedObject = placementComponent.selectedObject else { return }
        guard selectedObject.matchesCollisionEvent(event: event) else { return }
        guard placementComponent.activeCollisions > 0 else { return }
        placementComponent.activeCollisions -= 1
    }
    
    @MainActor
    func select(_ object: PlaceableObjectEntity?) {
        if let oldSelection = placementComponent.selectedObject {
            placementLocation.removeChild(oldSelection.previewEntity)
            if oldSelection.descriptor.fileName == object?.descriptor.fileName {
                select(nil)
                return
            }
        }
        placementComponent.selectedObject = object
        appComponent?.selectedFileName = object?.descriptor.fileName
        if let object {
            placementLocation.addChild(object.previewEntity)
        }
    }

    @MainActor
    func processWorldAnchorUpdates() async {
        for await anchorUpdate in worldTracking.anchorUpdates {
            persistenceSystem.process(anchorUpdate)
        }
    }
    
    @MainActor
    func processDeviceAnchorUpdates() async {
        await run(function: queryAndProcessLatestDeviceAnchor, withFrequency: 90)
    }
    
    @MainActor
    private func queryAndProcessLatestDeviceAnchor() async {
        guard worldTracking.state == .running else { return }
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        placementComponent.deviceAnchorPresent = (deviceAnchor != nil)
        placementComponent.planeAnchorsPresent = !planeAnchorSystem.planeAnchors.isEmpty
        placementComponent.selectedObject?.previewEntity.isEnabled = placementComponent.shouldShowPreview
        
        guard let deviceAnchor, deviceAnchor.isTracked else { return }
        await updateUserFacingUIOrientations(deviceAnchor)
        await checkWhichObjectDeviceIsPointingAt(deviceAnchor)
        await updatePlacementLocation(deviceAnchor)
    }
    
    @MainActor
    private func updateUserFacingUIOrientations(_ deviceAnchor: DeviceAnchor) async {
        if let uiOrigin = placementComponent.highlightedObject?.uiOrigin {
            uiOrigin.look(
                at: deviceAnchor.originFromAnchorTransform.translation,
                from: uiOrigin.position(relativeTo: nil),
                relativeTo: nil
            )
            let uiRotationOnYAxis = uiOrigin.transformMatrix(relativeTo: nil).gravityAligned.rotation
            uiOrigin.setOrientation(uiRotationOnYAxis, relativeTo: nil)
        }
        for entity in [placementTooltip, dragTooltip, deleteButton] {
            entity?.look(
                at: deviceAnchor.originFromAnchorTransform.translation,
                from: entity?.position(relativeTo: nil) ?? .zero,
                upVector: [0, 1, 0],
                relativeTo: nil
            )
        }
    }
    
    @MainActor
    private func updatePlacementLocation(_ deviceAnchor: DeviceAnchor) async {
        deviceLocation.transform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
        let originFromUpright = deviceAnchor.originFromAnchorTransform.gravityAligned
        let origin = raycastOrigin.transformMatrix(relativeTo: nil).translation
        let direction = -raycastOrigin.transformMatrix(relativeTo: nil).zAxis
        let minDistance: Float = 0.2
        let maxDistance: Float = 3
        let collisionMask = PlaneAnchor.horizontalCollisionGroup.rawValue | PlaneAnchor.verticalCollisionGroup.rawValue
        var originFromPointOnPlaneTransform: float4x4? = nil
        
        if let result = rootEntity.scene?.raycast(origin: origin, direction: direction, length: maxDistance, query: .nearest, mask: CollisionGroup(rawValue: collisionMask)).first,
           result.distance > minDistance {
            if result.entity.components[CollisionComponent.self]?.filter.group != PlaneAnchor.verticalCollisionGroup {
                originFromPointOnPlaneTransform = originFromUpright
                originFromPointOnPlaneTransform?.translation = result.position + [0.0, Self.placedObjectsOffsetOnPlanes, 0.0]
            }
        }
        
        if let originFromPointOnPlaneTransform {
            placementLocation.transform = Transform(matrix: originFromPointOnPlaneTransform)
            placementComponent.planeToProjectOnFound = true
        } else {
            let distanceFromDeviceAnchor: Float = 0.5
            let downwardsOffset: Float = 0.3
            var uprightDeviceAnchorFromOffsetTransform = matrix_identity_float4x4
            uprightDeviceAnchorFromOffsetTransform.translation = [0, -downwardsOffset, -distanceFromDeviceAnchor]
            let originFromOffsetTransform = originFromUpright * uprightDeviceAnchorFromOffsetTransform
            placementLocation.transform = Transform(matrix: originFromOffsetTransform)
            placementComponent.planeToProjectOnFound = false
        }
    }
    
    @MainActor
    private func checkWhichObjectDeviceIsPointingAt(_ deviceAnchor: DeviceAnchor) async {
        let origin = raycastOrigin.transformMatrix(relativeTo: nil).translation
        let direction = -raycastOrigin.transformMatrix(relativeTo: nil).zAxis
        if let result = rootEntity.scene?.raycast(origin: origin, direction: direction, query: .nearest, mask: PlacedObjectEntity.collisionGroup).first {
            if let pointedAtObject = persistenceSystem.object(for: result.entity) {
                setHighlightedObject(pointedAtObject)
            } else {
                setHighlightedObject(nil)
            }
        } else {
            setHighlightedObject(nil)
        }
    }
    
    @MainActor
    func setHighlightedObject(_ objectToHighlight: PlacedObjectEntity?) {
        guard placementComponent.highlightedObject !== objectToHighlight else { return }
        placementComponent.highlightedObject = objectToHighlight
        guard let deleteButton, let dragTooltip else { return }
        deleteButton.removeFromParent()
        dragTooltip.removeFromParent()
        guard let objectToHighlight else { return }
        let extents = objectToHighlight.extents
        let topLeftCorner: SIMD3<Float> = [-extents.x / 2, (extents.y / 2) + 0.02, 0]
        let frontBottomCenter: SIMD3<Float> = [0, (-extents.y / 2) + 0.04, extents.z / 2 + 0.04]
        deleteButton.position = topLeftCorner
        dragTooltip.position = frontBottomCenter
        objectToHighlight.uiOrigin.addChild(deleteButton)
        deleteButton.scale = 1 / objectToHighlight.scale
        objectToHighlight.uiOrigin.addChild(dragTooltip)
        dragTooltip.scale = 1 / objectToHighlight.scale
    }

    func removeAllPlacedObjects() async {
        await persistenceSystem.removeAllPlacedObjects()
    }

    func processPlaneDetectionUpdates() async {
        for await anchorUpdate in planeDetection.anchorUpdates {
            await planeAnchorSystem.process(anchorUpdate)
        }
    }
    
    @MainActor
    func placeSelectedObject() {
        guard let objectToPlace = placementComponent.objectToPlace else { return }
        let object = objectToPlace.materialize()
        object.position = placementLocation.position
        object.orientation = placementLocation.orientation
        Task {
            await persistenceSystem.attachObjectToWorldAnchor(object)
        }
        placementComponent.userPlacedAnObject = true
    }
    
    @MainActor
    func checkIfAnchoredObjectsNeedToBeDetached() async {
        await run(function: persistenceSystem.checkIfAnchoredObjectsNeedToBeDetached, withFrequency: 10)
    }
    
    @MainActor
    func checkIfMovingObjectsCanBeAnchored() async {
        await run(function: persistenceSystem.checkIfMovingObjectsCanBeAnchored, withFrequency: 2)
    }
    
    @MainActor
    func updateDrag(value: EntityTargetValue<DragGesture.Value>) {
        if let currentDrag, currentDrag.draggedObject !== value.entity {
            endDrag()
        }
        if currentDrag == nil {
            guard let object = persistenceSystem.object(for: value.entity) else { return }
            object.isBeingDragged = true
            currentDrag = DragComponent(objectToDrag: object)
            placementComponent.userDraggedAnObject = true
        }
        if let currentDrag {
            currentDrag.draggedObject.position = currentDrag.initialPosition + value.convert(value.translation3D, from: .local, to: rootEntity)
            let maxDistance = Self.snapToPlaneDistanceForDraggedObjects
            if let projectedTransform = PlaneProjector.project(
                point: currentDrag.draggedObject.transform.matrix,
                ontoHorizontalPlaneIn: planeAnchorSystem.planeAnchors,
                withMaxDistance: maxDistance
            ) {
                currentDrag.draggedObject.position = projectedTransform.translation
            }
        }
    }
    
    @MainActor
    func endDrag() {
        guard let currentDrag else { return }
        currentDrag.draggedObject.isBeingDragged = false
        self.currentDrag = nil
    }
}

extension PlacementSystem {
    @MainActor
    func run(function: () async -> Void, withFrequency hz: UInt64) async {
        while true {
            if Task.isCancelled { return }
            let nsToSleep: UInt64 = 1_000_000_000 / hz
            do {
                try await Task.sleep(nanoseconds: nsToSleep)
            } catch {
                return
            }
            await function()
        }
    }
}
