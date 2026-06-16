//
//  WatchSessionDelegate.swift
//  RunCraftWatch Watch App
//
//  Created by Cheng Lung, Lin on 2026/6/15.
//
// WCSession is now managed by WatchAppDelegate, which activates it in
// applicationDidFinishLaunching so receivedApplicationContext is populated
// before handle(_:HKWorkoutConfiguration) fires. This file is kept only
// for the WatchStatus type used by WatchStatusView.

enum WatchStatus: Equatable {
    case idle
    case starting
    case failed(String)
}
