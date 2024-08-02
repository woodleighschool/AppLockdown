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
        dateFormatter.locale = Locale(identifier: "en_AU")
        dateFormatter.dateFormat = "HH:mm"  // 24-hour format
        let currentTime = dateFormatter.string(from: Date())
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
            }
        }
        if !isWithinRestrictedTime {
            print("Current time \(currentTime) is not within any restricted times.")
        }
    }

    private func timeIsWithinRestriction(_ currentTime: String, _ restriction: String) -> Bool {
        let times = restriction.split(separator: "-").map(String.init)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.dateFormat = "HH:mm"
        guard let start = formatter.date(from: times[0]), let end = formatter.date(from: times[1]), let current = formatter.date(from: currentTime) else {
            print("Error parsing times in restriction.")
            return false
        }
        return current >= start && current <= end
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
