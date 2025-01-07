//
//  PlacedObjectEntity.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//
import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

class PlacedObjectEntity: Entity, ECSComponent {
    let fileName: String
    private let renderContent: ModelEntity
    static let collisionGroup = CollisionGroup(rawValue: 1 << 29)
    let uiOrigin = Entity()
    var affectedByPhysics = false {
        didSet {
            guard affectedByPhysics != oldValue else { return }
            if affectedByPhysics {
                components[PhysicsBodyComponent.self]!.mode = .dynamic
            } else {
                components[PhysicsBodyComponent.self]!.mode = .static
            }
        }
    }
    var isBeingDragged = false {
        didSet {
            affectedByPhysics = !isBeingDragged
        }
    }
    var positionAtLastReanchoringCheck: SIMD3<Float>?
    var atRest = false
    
    init(descriptor: ModelDescriptorComponent, renderContentToClone: ModelEntity, shapes: [ShapeResource]) {
        fileName = descriptor.fileName
        renderContent = renderContentToClone.clone(recursive: true)
        super.init()
        name = renderContent.name
        scale = renderContent.scale
        renderContent.scale = .one
        let physicsMaterial = PhysicsMaterialResource.generate(restitution: 0.0)
        let physicsBodyComponent = PhysicsBodyComponent(shapes: shapes, mass: 1.0, material: physicsMaterial, mode: .static)
        components.set(physicsBodyComponent)
        components.set(CollisionComponent(shapes: shapes, isStatic: false,
                                          filter: CollisionFilter(group: Self.collisionGroup, mask: .all)))
        uiOrigin.position.y = extents.y / 2
        components.set(InputTargetComponent(allowedInputTypes: [.direct, .indirect]))
        renderContent.components.set(GroundingShadowComponent(castsShadow: true))
        addChild(renderContent)
        addChild(uiOrigin)
    }
    
    required init() {
        fatalError("`init` is unimplemented.")
    }
}
