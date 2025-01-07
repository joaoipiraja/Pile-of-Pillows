//
//  ObjectPlacementRealityView.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation


@MainActor
struct ObjectPlacementRealityView: View {
    var appComponent: AppComponent
    @State private var placementSystem = PlacementSystem()
    @State private var collisionBeganSubscription: EventSubscription? = nil
    @State private var collisionEndedSubscription: EventSubscription? = nil
    
    private enum Attachments {
        case placementTooltip
        case dragTooltip
        case deleteButton
    }

    var body: some View {
        RealityView { content, attachments in
            content.add(placementSystem.rootEntity)
            placementSystem.appComponent = appComponent
            
            if let placementTooltipAttachment = attachments.entity(for: Attachments.placementTooltip) {
                placementSystem.addPlacementTooltip(placementTooltipAttachment)
            }
            if let dragTooltipAttachment = attachments.entity(for: Attachments.dragTooltip) {
                placementSystem.dragTooltip = dragTooltipAttachment
            }
            if let deleteButtonAttachment = attachments.entity(for: Attachments.deleteButton) {
                placementSystem.deleteButton = deleteButtonAttachment
            }
            
            collisionBeganSubscription = content.subscribe(to: CollisionEvents.Began.self) { [weak placementSystem] event in
                placementSystem?.collisionBegan(event)
            }
            collisionEndedSubscription = content.subscribe(to: CollisionEvents.Ended.self) { [weak placementSystem] event in
                placementSystem?.collisionEnded(event)
            }
            
            Task {
                await placementSystem.runARKitSession()
            }
        } update: { update, attachments in
            let placementState = placementSystem.placementComponent
            if let placementTooltip = attachments.entity(for: Attachments.placementTooltip) {
                placementTooltip.isEnabled = (placementState.selectedObject != nil && placementState.shouldShowPreview)
            }
            if let dragTooltip = attachments.entity(for: Attachments.dragTooltip) {
                dragTooltip.isEnabled = !placementState.userDraggedAnObject
            }
            if let selectedObject = placementState.selectedObject {
                selectedObject.isPreviewActive = placementState.isPlacementPossible
            }
        } attachments: {
            Attachment(id: Attachments.placementTooltip) {
                PlacementTooltip(placementComponent: placementSystem.placementComponent)
            }
            Attachment(id: Attachments.dragTooltip) {
                TooltipView(text: "Arraste para reposicionar")
            }
            Attachment(id: Attachments.deleteButton) {
                DeleteButton {
                    Task {
                        await placementSystem.removeHighlightedObject()
                    }
                }
            }
        }
        .task {
            await placementSystem.processWorldAnchorUpdates()
        }
        .task {
            await placementSystem.processDeviceAnchorUpdates()
        }
        .task {
            await placementSystem.processPlaneDetectionUpdates()
        }
        .task {
            await placementSystem.checkIfAnchoredObjectsNeedToBeDetached()
        }
        .task {
            await placementSystem.checkIfMovingObjectsCanBeAnchored()
        }
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded { event in
            if event.entity.components[CollisionComponent.self]?.filter.group == PlaceableObjectEntity.previewCollisionGroup {
                placementSystem.placeSelectedObject()
            }
        })
        .gesture(DragGesture()
            .targetedToAnyEntity()
            .handActivationBehavior(.pinch)
            .onChanged { value in
                if value.entity.components[CollisionComponent.self]?.filter.group == PlacedObjectEntity.collisionGroup {
                    placementSystem.updateDrag(value: value)
                }
            }
            .onEnded { value in
                if value.entity.components[CollisionComponent.self]?.filter.group == PlacedObjectEntity.collisionGroup {
                    placementSystem.endDrag()
                }
            }
        )
        .onAppear {
            appComponent.immersiveSpaceOpened(with: placementSystem)
        }
        .onDisappear {
            appComponent.didLeaveImmersiveSpace()
        }
    }
}


