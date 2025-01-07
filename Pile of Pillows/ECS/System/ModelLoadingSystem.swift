//
//  ModelLoadingSystem.swift
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
@Observable
final class ModelLoadingSystem: ECSSystem {
    private var didStartLoading = false
    private(set) var progress: Float = 0.0
    private(set) var placeableObjects = [PlaceableObjectEntity]()
    private var fileCount: Int = 0
    private var filesLoaded: Int = 0
    
    init(progress: Float? = nil) {
        if let progress {
            self.progress = progress
        }
    }
    var didFinishLoading: Bool {
        progress >= 1.0
    }
    
    private func updateProgress() {
        filesLoaded += 1
        if fileCount == 0 {
            progress = 0.0
        } else if filesLoaded == fileCount {
            progress = 1.0
        } else {
            progress = Float(filesLoaded) / Float(fileCount)
        }
    }

    func loadObjects() async {
        guard !didStartLoading else { return }
        didStartLoading = true
        
        var usdzFiles: [String] = []
        if let resourcesPath = Bundle.main.resourcePath {
            do {
                usdzFiles = try FileManager.default.contentsOfDirectory(atPath: resourcesPath)
                    .filter { $0.hasSuffix(".usdz") }
            } catch {
                print("Error enumerating .usdz files: \(error)")
            }
        }
        assert(!usdzFiles.isEmpty, "Add USDZ files to your app's resource folder.")
        
        fileCount = usdzFiles.count
        await withTaskGroup(of: Void.self) { group in
            for usdz in usdzFiles {
                let fileName = URL(fileURLWithPath: usdz).deletingPathExtension().lastPathComponent
                group.addTask {
                    await self.loadObject(fileName)
                    await self.updateProgress()
                }
            }
        }
    }
    
    func loadObject(_ fileName: String) async {
        var modelEntity: ModelEntity
        var previewEntity: Entity
        do {
            try await modelEntity = ModelEntity(named: fileName)
            try await previewEntity = Entity(named: fileName)
            previewEntity.name = "Preview of \(modelEntity.name)"
        } catch {
            fatalError("Failed to load model \(fileName)")
        }

        do {
            let shape = try await ShapeResource.generateConvex(from: modelEntity.model!.mesh)
            previewEntity.components.set(
                CollisionComponent(
                    shapes: [shape],
                    isStatic: false,
                    filter: CollisionFilter(group: PlaceableObjectEntity.previewCollisionGroup, mask: .all)
                )
            )
            let previewInput = InputTargetComponent(allowedInputTypes: [.indirect])
            previewEntity.components[InputTargetComponent.self] = previewInput
        } catch {
            fatalError("Failed to generate shape resource for model \(fileName)")
        }

        let descriptor = ModelDescriptorComponent(
            fileName: fileName,
            displayName: modelEntity.displayName
        )
        placeableObjects.append(
            PlaceableObjectEntity(
                descriptor: descriptor,
                renderContent: modelEntity,
                previewEntity: previewEntity
            )
        )
    }
}

fileprivate extension ModelEntity {
    var displayName: String? {
        !name.isEmpty ? name.replacingOccurrences(of: "_", with: " ") : nil
    }
}
