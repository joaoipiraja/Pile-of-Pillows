//
//  TooltipView.swift
//  ObjectPlacement
//
//  Created by João Victor Ipirajá de Alencar on 06/01/25.
//
import SwiftUI

struct TooltipView: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 220)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .glassBackgroundEffect()
            .allowsHitTesting(false)
    }
}
