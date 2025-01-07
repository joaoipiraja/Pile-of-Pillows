//
//  DeleteButton.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//
import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

struct DeleteButton: View {
    var deletionHandler: (() -> Void)?

    var body: some View {
        Button {
            deletionHandler?()
        } label: {
            Image(systemName: "trash")
        }
        .accessibilityLabel("Excluir objeto")
        .glassBackgroundEffect()
    }
}
