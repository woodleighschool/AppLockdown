//
//  PlistReader.swift
//  App Lockdown
//
//  Created by Alexander Hyde on 1/8/2024.
//

import Foundation

class JSONFetcher {
    var configurationURL: URL
    var processManager: ProcessManager?
    
    init(url: String) {
        self.configurationURL = URL(string: url)!
    }
    
    func fetchConfiguration() {
        let task = URLSession.shared.dataTask(with: configurationURL) { [weak self] data, response, error in
            guard let data = data, error == nil else { return }
            self?.parseConfiguration(data: data)
        }
        task.resume()
    }
    
    private func parseConfiguration(data: Data) {
        do {
            let decoder = JSONDecoder()
            let configuration = try decoder.decode(Configuration.self, from: data)
            DispatchQueue.main.async {
                self.processManager = ProcessManager(configuration: configuration)
                print("Configuration loaded and monitoring setup")
            }
        } catch {
            print("Error parsing configuration: \(error)")
        }
    }
}
