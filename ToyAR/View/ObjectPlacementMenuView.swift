//
//  ObjectPlacementMenuView.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation


struct ObjectPlacementMenuView: View {
    let appComponent: AppComponent
    
    var body: some View {
        ObjectSelectionView(
            modelDescriptors: appComponent.modelDescriptors,
            selectedFileName: appComponent.selectedFileName
        ) { descriptor in
            if let placeable = appComponent.placeableObjectsByFileName[descriptor.fileName],
               let placementSystem = appComponent.placementSystem {
                placementSystem.select(placeable)
            }
        }
    }
}
