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
    var currentlyAlerting = Set<String>()

    init(configuration: Configuration) {
        self.configuration = configuration
        setupProcessMonitoring()
        print("ProcessManager initialized and monitoring started.")
    }

    private func setupProcessMonitoring() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(
            self,
            selector: #selector(appLaunched(notification:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        print("Notification observer for app launches set up.")
    }

    @objc func appLaunched(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName else {
            print("Failed to retrieve app information from notification.")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_AU")
        dateFormatter.dateFormat = "HH:mm"
        let currentTime = dateFormatter.string(from: Date())
        let today = Calendar.current.component(.weekday, from: Date())
        
        guard let restrictions = configuration.restrictedHours[Day(rawValue: today)?.description ?? ""] else {
            print("No restrictions found for today.")
            return
        }

        var isWithinRestrictedTime = false
        for restriction in restrictions {
            if timeIsWithinRestriction(currentTime, restriction) && isRestrictedApp(appName: appName) {
                isWithinRestrictedTime = true
                terminate(app: app)
                if !currentlyAlerting.contains(appName) {
                    showAlert(processName: appName, icon: app.icon)
                }
                return
            }
        }

        if !isWithinRestrictedTime {
            print("Current time \(currentTime) is not within any restricted times.")
        }
    }

    private func terminate(app: NSRunningApplication) {
        print("Terminating app: \(app.localizedName ?? "Unknown")")
        kill(pid_t(app.processIdentifier), SIGKILL)
    }

    private func showAlert(processName: String, icon: NSImage?) {
        print("Alert: Restricted Process Terminated - \(processName)")
        let alert = NSAlert()
        alert.messageText = "Restricted Process Terminated"
        alert.informativeText = "You are not permitted to access \(processName) during restricted hours."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.icon = icon
        currentlyAlerting.insert(processName)
        alert.runModal()
        currentlyAlerting.remove(processName)  // Remove from set once alert is dismissed
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
        return false
    }
}
