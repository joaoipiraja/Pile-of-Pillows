//
//  ObjectSelectionView.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//
import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation


struct ObjectSelectionView: View {
    let modelDescriptors: [ModelDescriptorComponent]
    var selectedFileName: String? = nil
    var selectionHandler: ((ModelDescriptorComponent) -> Void)? = nil
    
    private func binding(for descriptor: ModelDescriptorComponent) -> Binding<Bool> {
        Binding<Bool>(
            get: { selectedFileName == descriptor.fileName },
            set: { _ in selectionHandler?(descriptor) }
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Escolha um objeto para colocar:")
                .padding(10)

            Grid {
                ForEach(0 ..< ((modelDescriptors.count + 1) / 2), id: \.self) { row in
                    GridRow {
                        ForEach(0 ..< 2, id: \.self) { column in
                            let descriptorIndex = row * 2 + column
                            if descriptorIndex < modelDescriptors.count {
                                let descriptor = modelDescriptors[descriptorIndex]
                                Toggle(isOn: binding(for: descriptor)) {
                                    Text(descriptor.displayName)
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .lineLimit(1)
                                }
                                .toggleStyle(.button)
                            }
                        }
                    }
                }
            }
        }
    }
}
