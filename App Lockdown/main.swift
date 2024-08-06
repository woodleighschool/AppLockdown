//
//  main.swift
//  App Lockdown
//
//  Created by Alexander Hyde on 1/8/2024.
//

import Foundation

let configLoader = ConfigLoader()

// Load initial configuration
configLoader.loadConfiguration()

// Setup timer to reload configuration every 60 seconds
Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
    configLoader.loadConfiguration()
}

// Main run loop to keep the application running
RunLoop.current.run()
