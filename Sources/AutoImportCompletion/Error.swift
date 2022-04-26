//
//  File.swift
//
//
//  Created by king on 2022/4/25.
//

import Foundation

enum AutoImportCompletionError: Error {
    case fileNotFound(String)
    case pathEmpty(String)
    case pathNotDirectory(String)
}
