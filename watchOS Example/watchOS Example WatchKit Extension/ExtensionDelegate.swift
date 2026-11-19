//
//  ExtensionDelegate.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import WatchKit
import Foundation

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering handle(backgroundTasks=\(backgroundTasks))\n".utf8))
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
				FileHandle.standardError.write(Data("[DEBUG] handle(backgroundTasks=\(backgroundTasks)): backgroundTask → \(backgroundTask)\n".utf8))
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
				FileHandle.standardError.write(Data("[DEBUG] handle(backgroundTasks=\(backgroundTasks)): snapshotTask → \(snapshotTask)\n".utf8))
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
				FileHandle.standardError.write(Data("[DEBUG] handle(backgroundTasks=\(backgroundTasks)): connectivityTask → \(connectivityTask)\n".utf8))
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
				FileHandle.standardError.write(Data("[DEBUG] handle(backgroundTasks=\(backgroundTasks)): urlSessionTask → \(urlSessionTask)\n".utf8))
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
				FileHandle.standardError.write(Data("[DEBUG] handle(backgroundTasks=\(backgroundTasks)): relevantShortcutTask → \(relevantShortcutTask)\n".utf8))
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
				FileHandle.standardError.write(Data("[DEBUG] handle(backgroundTasks=\(backgroundTasks)): intentDidRunTask → \(intentDidRunTask)\n".utf8))
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
				FileHandle.standardError.write(Data("[DEBUG] handle(backgroundTasks=\(backgroundTasks)): task → \(task)\n".utf8))
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting handle(backgroundTasks=\(backgroundTasks))\n".utf8))
    }
}
