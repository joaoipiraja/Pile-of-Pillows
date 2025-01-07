//
//  InfoLabel.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//
import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

struct InfoLabel: View {
    let appComponent: AppComponent
    
    var body: some View {
        Text(infoMessage)
            .font(.subheadline)
            .multilineTextAlignment(.center)
    }

    var infoMessage: String {
        if !appComponent.allRequiredProvidersAreSupported {
            return "Este aplicativo requer funcionalidades que não são compatíveis com o Simulador."
        } else if !appComponent.allRequiredAuthorizationsAreGranted {
            return "Este aplicativo está sem as autorizações necessárias. Altere isso em Configurações > Privacidade e Segurança."
        } else {
            return "Coloque e mova modelos 3D no seu ambiente físico. O sistema mantém a posição deles mesmo após reiniciar o aplicativo."
        }
    }
}
