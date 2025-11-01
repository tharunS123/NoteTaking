//
//  SecretDecode.swift
//  NoteTaking
//
//  Created by Tharun Senthilkumar on 10/31/25.
//

import Foundation

enum Secrets{
    static var openrouterAPIKey: String {
        guard let key = Bundle.main.infoDictionary?["OPENROUTER_API_KEY"] as? String else {
            fatalError("OpenRouterAPIKey not found in Info.plist")
        }
        return key
    }
}
