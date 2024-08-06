//
//  ConfigLoader.swift
//  App Lockdown
//
//  Created by Alexander Hyde on 1/8/2024.
//

import Foundation

class ConfigLoader {
    var processManager: ProcessManager?

    func loadConfiguration() {
        guard let userDefaults = UserDefaults(suiteName: "au.edu.vic.woodleigh.app-lockdown") else {
            print("Unable to access UserDefaults.")
            return
        }

        let processes = userDefaults.array(forKey: "processes") as? [String] ?? []
        let restrictedHoursDict = userDefaults.dictionary(forKey: "restrictedHours") as? [String: [String]] ?? [:]
        
        if processes.isEmpty && restrictedHoursDict.isEmpty {
            print("Configuration is empty or missing. Continuing without config...")
            return
        }
        
        let configuration = Configuration(processes: processes, restrictedHours: restrictedHoursDict)
        DispatchQueue.main.async {
            if self.processManager == nil {
                self.processManager = ProcessManager(configuration: configuration)
            } else {
                self.processManager?.updateConfiguration(configuration: configuration)
            }
        }
    }
}
