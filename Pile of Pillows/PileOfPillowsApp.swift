import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

private enum UIIdentifier {
    static let immersiveSpace = "Object Placement"
}

protocol ECSComponent {}
protocol ECSSystem {}

extension Entity {
    var extents: SIMD3<Float> {
        self.visualBounds(relativeTo: self).extents
    }
    
    func applyMaterial(_ material: RealityFoundation.Material) {
        if let modelEntity = self as? ModelEntity {
            modelEntity.model?.materials = [material]
        }
        for child in children {
            child.applyMaterial(material)
        }
    }
}

@main
@MainActor
struct PileOfPillowsApp: App {
    @State private var appComponent = AppComponent()
    @State private var modelLoadingSystem = ModelLoadingSystem()
    
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.scenePhase) private var scenePhase

    var body: some SwiftUI.Scene {
        WindowGroup {
            HomeView(
                appComponent: appComponent,
                modelLoadingSystem: modelLoadingSystem,
                immersiveSpaceIdentifier: UIIdentifier.immersiveSpace
            )
            .task {
                await modelLoadingSystem.loadObjects()
                appComponent.setPlaceableObjects(modelLoadingSystem.placeableObjects)
            }
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)

        ImmersiveSpace(id: UIIdentifier.immersiveSpace) {
            ObjectPlacementRealityView(appComponent: appComponent)
        }
        .onChange(of: scenePhase, initial: true) {
            if scenePhase != .active {
                if appComponent.immersiveSpaceOpened {
                    Task {
                        await dismissImmersiveSpace()
                        appComponent.didLeaveImmersiveSpace()
                    }
                }
            }
        }
    }
}
