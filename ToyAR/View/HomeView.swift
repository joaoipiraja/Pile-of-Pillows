//
//  HomeView.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//

import SwiftUI
import RealityKit
import UIKit
import ARKit
import Foundation

struct HomeView: View {
    let appComponent: AppComponent
    let modelLoadingSystem: ModelLoadingSystem
    let immersiveSpaceIdentifier: String

    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack {
            VStack(spacing: 20) {
                Text("Toy AR")
                    .font(.title)

                InfoLabel(appComponent: appComponent)
                    .padding(.horizontal, 30)
                    .frame(width: 400)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if !modelLoadingSystem.didFinishLoading {
                        VStack(spacing: 10) {
                            Text("Carregando…")
                            ProgressView(value: modelLoadingSystem.progress)
                                .frame(maxWidth: 200)
                        }
                    } else if !appComponent.immersiveSpaceOpened {
                        Button("Enter") {
                            Task {
                                switch await openImmersiveSpace(id: immersiveSpaceIdentifier) {
                                case .opened: break
                                case .error:
                                    print("Error opening immersive space \(immersiveSpaceIdentifier)")
                                case .userCancelled:
                                    print("User cancelled immersive space \(immersiveSpaceIdentifier)")
                                @unknown default: break
                                }
                            }
                        }
                        .disabled(!appComponent.canEnterImmersiveSpace)
                    }
                }
                .padding(.top, 10)
            }
            .padding(.vertical, 24)
            .glassBackgroundEffect()

            if appComponent.immersiveSpaceOpened {
                ObjectPlacementMenuView(appComponent: appComponent)
                    .padding(20)
                    .glassBackgroundEffect()
            }
        }
        .fixedSize()
        .onChange(of: scenePhase, initial: true) {
            if scenePhase == .active {
                Task {
                    await appComponent.queryWorldSensingAuthorization()
                }
            } else {
                if appComponent.immersiveSpaceOpened {
                    Task {
                        await dismissImmersiveSpace()
                        appComponent.didLeaveImmersiveSpace()
                    }
                }
            }
        }
        .onChange(of: appComponent.providersStoppedWithError, { _, providersStoppedWithError in
            if providersStoppedWithError {
                if appComponent.immersiveSpaceOpened {
                    Task {
                        await dismissImmersiveSpace()
                        appComponent.didLeaveImmersiveSpace()
                    }
                }
                appComponent.providersStoppedWithError = false
            }
        })
        .task {
            if appComponent.allRequiredProvidersAreSupported {
                await appComponent.requestWorldSensingAuthorization()
            }
        }
        .task {
            await appComponent.monitorSessionEvents()
        }
    }
}
