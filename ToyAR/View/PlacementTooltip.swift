//
//  PlacementTooltip.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI

struct PlacementTooltip: View {
    var placementComponent: PlacementComponent
    var body: some View {
        if let message {
            TooltipView(text: message)
        }
    }

    var message: String? {
        if !placementComponent.planeToProjectOnFound {
            return "Aponte o dispositivo para uma superfície horizontal próxima"
        }
        if placementComponent.collisionDetected {
            return "O espaço está ocupado."
        }
        if !placementComponent.userPlacedAnObject {
            return "Toque para posicionar objetos."
        }
        return nil
    }
}
