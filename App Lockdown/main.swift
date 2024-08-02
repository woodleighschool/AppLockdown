//
//  main.swift
//  App Lockdown
//
//  Created by Alexander Hyde on 1/8/2024.
//

import Foundation

let jsonFetcher = JSONFetcher(url: "https://hyde.services/config.json")
jsonFetcher.fetchConfiguration()

// Set up a timer to fetch configuration every hour
Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
    jsonFetcher.fetchConfiguration()
}

// Main run loop to keep the application running
RunLoop.current.run()
