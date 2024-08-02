//
//  ProcessManager.swift
//  App Lockdown
//
//  Created by Alexander Hyde on 1/8/2024.
//

import Foundation
import Cocoa

class ProcessManager {
    var configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
        setupProcessMonitoring()  // Start monitoring when instance is created.
        print("ProcessManager initialized and monitoring started.")
    }

    private func setupProcessMonitoring() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(
            self,
            selector: #selector(appLaunched(notification:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil  // It's fine to keep object nil here
        )
        print("Notification observer for app launches set up.")
    }

    @objc func appLaunched(notification: Notification) {
        print("Application launch detected.")
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName else {
            print("Failed to retrieve app information from notification.")
            return
        }

        print("Launched app: \(appName)")
        // Create a DateFormatter to format the Date object to a string in 24-hour time
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_GB")  // Using UK locale to enforce 24-hour time format
        dateFormatter.dateFormat = "HH:mm"  // 24-hour format
        let currentTime = dateFormatter.string(from: Date())
        print("Debug: Current Time - \(currentTime)")
        let today = Calendar.current.component(.weekday, from: Date())

        guard let restrictions = configuration.restrictedHours[Day(rawValue: today)?.description ?? ""] else {
            print("No restrictions found for today.")
            return
        }

        var isWithinRestrictedTime = false
        for restriction in restrictions {
            if timeIsWithinRestriction(currentTime, restriction) {
                isWithinRestrictedTime = true
                print("Current time \(currentTime) is within the restricted time \(restriction).")
                if isRestrictedApp(appName: appName) {
                    terminate(app: app)
                    return
                }
            } else {
                print("Current time \(currentTime) is not within the restricted time \(restriction).")
            }
        }
        if !isWithinRestrictedTime {
            print("Current time \(currentTime) is not within any restricted times.")
        }
    }

    private func timeIsWithinRestriction(_ currentTime: String, _ restriction: String) -> Bool {
        let times = restriction.split(separator: "-").map(String.init)
        if times.count != 2 {
            return false
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB") // Ensure 24-hour format
        formatter.dateFormat = "HH:mm"

        if let start = formatter.date(from: times[0]), let end = formatter.date(from: times[1]), let current = formatter.date(from: currentTime) {
            print("Debug: Parsed Times - Start: \(formatter.string(from: start)), End: \(formatter.string(from: end)), Current: \(formatter.string(from: current))")
            return current >= start && current <= end
        } else {
            print("Error parsing times in restriction. Start: \(times[0]), End: \(times[1]), Current: \(currentTime)")
            if formatter.date(from: times[0]) == nil {
                print("Debug: Failed to parse start time - \(times[0])")
            }
            if formatter.date(from: times[1]) == nil {
                print("Debug: Failed to parse end time - \(times[1])")
            }
            if formatter.date(from: currentTime) == nil {
                print("Debug: Failed to parse current time - \(currentTime)")
            }
            return false
        }
    }

    private func isRestrictedApp(appName: String) -> Bool {
        for process in configuration.processes {
            if process.starts(with: "regex:") {
                let patternIndex = process.index(process.startIndex, offsetBy: 6) // Skip 'regex:' part
                let pattern = String(process[patternIndex...])
                if let _ = appName.range(of: pattern, options: .regularExpression) {
                    print("App \(appName) matches regex \(pattern) and is restricted.")
                    return true
                }
            } else if appName == process {
                print("App \(appName) is explicitly restricted.")
                return true
            }
        }
        print("App \(appName) is not restricted.")
        return false
    }

    private func terminate(app: NSRunningApplication) {
        print("Terminating app: \(app.localizedName ?? "Unknown")")
        kill(pid_t(app.processIdentifier), SIGKILL) // Use pid_t for correct type
        showAlert(processName: app.localizedName ?? "Unknown")
    }

    private func showAlert(processName: String) {
        print("Alert: Restricted Process Terminated - \(processName)")
        let alert = NSAlert()
        alert.messageText = "Restricted Process Terminated"
        alert.informativeText = "You are not permitted to access \(processName) during restricted hours."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
