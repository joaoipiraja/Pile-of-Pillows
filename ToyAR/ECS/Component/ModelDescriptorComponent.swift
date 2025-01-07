//
//  ModelDescriptorComponent.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

struct ModelDescriptorComponent: Identifiable, Hashable, ECSComponent {
    let fileName: String
    let displayName: String
    var id: String { fileName }
    init(fileName: String, displayName: String? = nil) {
        self.fileName = fileName
        self.displayName = displayName ?? fileName
    }
}
