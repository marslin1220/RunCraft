//
//  WatchHomeView.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/16.
//

import AppleWatchSync
import SwiftUI

struct WatchHomeView: View {
    let schedule: WatchSchedulePayload?
    @ObservedObject var manager: WorkoutSessionManager

    var body: some View {
        NavigationStack {
            if let schedule, !schedule.sessions.isEmpty || !schedule.paceTemplates.isEmpty {
                List {
                    if !schedule.sessions.isEmpty {
                        Section("This Week") {
                            ForEach(schedule.sessions) { session in
                                NavigationLink {
                                    WorkoutStartView(
                                        name: session.title,
                                        payload: session.payload,
                                        manager: manager
                                    )
                                } label: {
                                    SessionRow(session: session)
                                }
                            }
                        }
                    }

                    if !schedule.paceTemplates.isEmpty {
                        Section("Training Paces") {
                            ForEach(schedule.paceTemplates, id: \.name) { template in
                                NavigationLink {
                                    WorkoutStartView(
                                        name: template.name,
                                        payload: template,
                                        manager: manager
                                    )
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                        if let sub = template.subtitle {
                                            Text(sub)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("RunCraft")
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Open RunCraft on your iPhone to sync your schedule.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .navigationTitle("RunCraft")
            }
        }
    }
}

// MARK: - SessionRow

private struct SessionRow: View {
    let session: WatchSchedulePayload.Session

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(session.dayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                if session.isToday {
                    Text("Today")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.tint, in: Capsule())
                }
            }
            Text(session.title)
                .font(.body)
        }
    }
}
