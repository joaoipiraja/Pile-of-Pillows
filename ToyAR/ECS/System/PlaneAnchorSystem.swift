//
//  PlaneAnchorSystem.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

class PlaneAnchorSystem: ECSSystem {
    var rootEntity: Entity
    private var planeEntities: [UUID: Entity] = [:]
    private var planeAnchorsByID: [UUID: PlaneAnchor] = [:]
    
    init(rootEntity: Entity) {
        self.rootEntity = rootEntity
    }

    var planeAnchors: [PlaneAnchor] {
        Array(planeAnchorsByID.values)
    }

    @MainActor
    func process(_ anchorUpdate: AnchorUpdate<PlaneAnchor>) async {
        let anchor = anchorUpdate.anchor
        if anchorUpdate.event == .removed {
            planeAnchorsByID.removeValue(forKey: anchor.id)
            if let oldEntity = planeEntities.removeValue(forKey: anchor.id) {
                oldEntity.removeFromParent()
            }
            return
        }
        planeAnchorsByID[anchor.id] = anchor
        let entity = Entity()
        entity.name = "Plane \(anchor.id)"
        entity.setTransformMatrix(anchor.originFromAnchorTransform, relativeTo: nil)
        
        do {
            let contents = MeshResource.Contents(planeGeometry: anchor.geometry)
            let mesh = try MeshResource.generate(from: contents)
            entity.components.set(ModelComponent(mesh: mesh, materials: [OcclusionMaterial()]))
        } catch {}
        
        do {
            let vertices = anchor.geometry.meshVertices.asSIMD3(ofType: Float.self)
            let shape = try await ShapeResource.generateStaticMesh(
                positions: vertices,
                faceIndices: anchor.geometry.meshFaces.asUInt16Array()
            )
            var collisionGroup = PlaneAnchor.verticalCollisionGroup
            if anchor.alignment == .horizontal {
                collisionGroup = PlaneAnchor.horizontalCollisionGroup
            }
            entity.components.set(
                CollisionComponent(
                    shapes: [shape],
                    isStatic: true,
                    filter: CollisionFilter(group: collisionGroup, mask: .all)
                )
            )
            let physicsMaterial = PhysicsMaterialResource.generate()
            let physics = PhysicsBodyComponent(shapes: [shape], mass: 0.0, material: physicsMaterial, mode: .static)
            entity.components.set(physics)
        } catch {}
        
        let oldEntity = planeEntities[anchor.id]
        planeEntities[anchor.id] = entity
        rootEntity.addChild(entity)
        oldEntity?.removeFromParent()
    }
}

enum PlaneProjector {
    static func project(
        point originFromPointTransform: matrix_float4x4,
        ontoHorizontalPlaneIn planeAnchors: [PlaneAnchor],
        withMaxDistance: Float
    ) -> matrix_float4x4? {
        let horizontalPlanes = planeAnchors.filter { $0.alignment == .horizontal }
        let inRangePlanes = horizontalPlanes.within(meters: withMaxDistance, of: originFromPointTransform)
        let containingPlanes = inRangePlanes.containing(pointToProject: originFromPointTransform)
        if let closestPlane = containingPlanes.closestPlane(to: originFromPointTransform) {
            var result = originFromPointTransform
            result.translation = [
                originFromPointTransform.translation.x,
                closestPlane.originFromAnchorTransform.translation.y,
                originFromPointTransform.translation.z
            ]
            return result
        }
        return nil
    }
}
