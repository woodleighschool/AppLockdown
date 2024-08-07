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
    var timer: Timer?

    init(configuration: Configuration) {
        self.configuration = configuration
        setupProcessMonitoring()
        checkAndTerminateExistingRestrictedProcesses()
        setupPreemptiveAlerts()
        print("ProcessManager initialized and monitoring started.")
    }

    func updateConfiguration(configuration: Configuration) {
        self.configuration = configuration
        checkAndTerminateExistingRestrictedProcesses()
        setupPreemptiveAlerts()
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

    private func setupPreemptiveAlerts() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkForPreemptiveAlerts()
        }
    }

    private func checkAndTerminateExistingRestrictedProcesses() {
        let apps = NSWorkspace.shared.runningApplications
        var alertApps = Set<String>()
        for app in apps {
            if let appName = app.localizedName, isRestrictedApp(appName: appName) {
                let currentTime = getCurrentTimeString()
                let today = Calendar.current.component(.weekday, from: Date())
                if let restrictions = configuration.restrictedHours[Day(rawValue: today)?.description ?? ""], restrictions.contains(where: { timeIsWithinRestriction(currentTime, $0) }) {
                    alertApps.insert(appName)
                    terminate(app: app)
                    showAlert(processName: appName, icon: app.icon)
                }
            }
        }
        if alertApps.count > 1 {
            sendGenericNotification(for: alertApps)
        }
    }

    @objc func appLaunched(notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName else {
            print("Failed to retrieve app information from notification.")
            return
        }

        if isRestrictedApp(appName: appName) {
            checkForImmediateTermination(app: app, appName: appName)
        }
    }

    private func checkForPreemptiveAlerts() {
        let apps = NSWorkspace.shared.runningApplications
        let currentTime = getCurrentTimeString()
        let today = Calendar.current.component(.weekday, from: Date())
        var upcomingApps = Set<String>()

        for app in apps {
            if let appName = app.localizedName, isRestrictedApp(appName: appName) {
                configuration.restrictedHours[Day(rawValue: today)?.description ?? ""]?.forEach { restriction in
                    if timeIsWithinPreemptiveAlert(currentTime, restriction) {
                        upcomingApps.insert(appName)
                    }
                }
            }
        }
        
        if upcomingApps.count > 0 {
            sendGenericNotification(for: upcomingApps)
        }
    }

    private func checkForImmediateTermination(app: NSRunningApplication, appName: String) {
        let currentTime = getCurrentTimeString()
        let today = Calendar.current.component(.weekday, from: Date())
        
        if let restrictions = configuration.restrictedHours[Day(rawValue: today)?.description ?? ""] {
            for restriction in restrictions {
                if timeIsWithinRestriction(currentTime, restriction) {
                    terminate(app: app)
                    showAlert(processName: appName, icon: app.icon)
                    return
                }
            }
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
        currentlyAlerting.remove(processName)
    }

    private func sendGenericNotification(for apps: Set<String>) {
        let notification = NSUserNotification()
        notification.title = "Upcoming Restricted Access"
        notification.informativeText = "The following apps will quit soon: \(apps.joined(separator: ", "))"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    private func timeIsWithinRestriction(_ currentTime: String, _ restriction: String) -> Bool {
        let times = restriction.split(separator: "-").map(String.init)
        return checkTime(currentTime, between: times[0], and: times[1])
    }

    private func timeIsWithinPreemptiveAlert(_ currentTime: String, _ restriction: String) -> Bool {
        let times = restriction.split(separator: "-").map(String.init)
        let start = shiftTimeBy(minutes: -5, from: times[0])
        return checkTime(currentTime, between: start, and: times[1])
    }

    private func checkTime(_ currentTime: String, between startTime: String, and endTime: String) -> Bool {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.dateFormat = "HH:mm"
        guard let start = formatter.date(from: startTime), let end = formatter.date(from: endTime), let current = formatter.date(from: currentTime) else {
            print("Error parsing times in restriction.")
            return false
        }
        return current >= start && current <= end
    }

    private func shiftTimeBy(minutes: Int, from time: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.dateFormat = "HH:mm"
        guard let date = formatter.date(from: time) else {
            return time
        }
        let newDate = Calendar.current.date(byAdding: .minute, value: minutes, to: date)!
        return formatter.string(from: newDate)
    }

    private func isRestrictedApp(appName: String) -> Bool {
        configuration.processes.contains(where: { process in
            if process.starts(with: "regex:") {
                let pattern = String(process.dropFirst(6)) // Skip 'regex:' part
                return appName.range(of: pattern, options: .regularExpression) != nil
            } else {
                return appName == process
            }
        })
    }

    private func getCurrentTimeString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_AU")
        dateFormatter.dateFormat = "HH:mm"
        return dateFormatter.string(from: Date())
    }
}
