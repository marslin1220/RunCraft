//
//  WatchStatusView.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/15.
//

import SwiftUI

struct WatchStatusView: View {
    let status: WatchStatus

    var body: some View {
        VStack(spacing: 8) {
            switch status {
            case .idle:
                Image(systemName: "figure.run")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text("Ready")
            case .starting:
                ProgressView()
                Text("Starting workout…")
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.yellow)
                Text("Couldn't start workout")
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .multilineTextAlignment(.center)
    }
}

#Preview("Idle") {
    WatchStatusView(status: .idle)
}

#Preview("Starting") {
    WatchStatusView(status: .starting)
}

#Preview("Failed") {
    WatchStatusView(status: .failed("Open RunCraft on your Apple Watch, then try again."))
}
