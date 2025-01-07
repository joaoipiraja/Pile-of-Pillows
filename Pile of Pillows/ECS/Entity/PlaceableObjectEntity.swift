//
//  PlaceableObjectEntity.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

private enum PreviewMaterials {
    static let active = UnlitMaterial(color: .gray.withAlphaComponent(0.5))
    static let inactive = UnlitMaterial(color: .gray.withAlphaComponent(0.1))
}

@MainActor
class PlaceableObjectEntity: ECSComponent {
    let descriptor: ModelDescriptorComponent
    var previewEntity: Entity
    private var renderContent: ModelEntity
    static let previewCollisionGroup = CollisionGroup(rawValue: 1 << 15)
    
    init(descriptor: ModelDescriptorComponent, renderContent: ModelEntity, previewEntity: Entity) {
        self.descriptor = descriptor
        self.previewEntity = previewEntity
        self.renderContent = renderContent
        self.previewEntity.applyMaterial(PreviewMaterials.active)
    }

    var isPreviewActive: Bool = true {
        didSet {
            if oldValue != isPreviewActive {
                previewEntity.applyMaterial(isPreviewActive ? PreviewMaterials.active : PreviewMaterials.inactive)
                previewEntity.components[InputTargetComponent.self]?.allowedInputTypes = isPreviewActive ? .indirect : []
            }
        }
    }

    func materialize() -> PlacedObjectEntity {
        let shapes = previewEntity.components[CollisionComponent.self]!.shapes
        return PlacedObjectEntity(descriptor: descriptor, renderContentToClone: renderContent, shapes: shapes)
    }

    func matchesCollisionEvent(event: CollisionEvents.Began) -> Bool {
        event.entityA == previewEntity || event.entityB == previewEntity
    }
    func matchesCollisionEvent(event: CollisionEvents.Ended) -> Bool {
        event.entityA == previewEntity || event.entityB == previewEntity
    }
    
    func attachPreviewEntity(to entity: Entity) {
        entity.addChild(previewEntity)
    }
}
