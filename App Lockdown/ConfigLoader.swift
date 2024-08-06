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
        
        let configuration = Configuration(processes: processes, restrictedHours: restrictedHoursDict)
        DispatchQueue.main.async {
            self.processManager = ProcessManager(configuration: configuration)
            print("Configuration loaded and monitoring setup")
        }
    }
}
