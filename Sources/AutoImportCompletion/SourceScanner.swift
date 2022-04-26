//
//  SourceScanner.swift
//
//
//  Created by king on 2022/4/26.
//

import Foundation
import PathKit

class SourceScanner {
    let path: Path

    init(path: Path) {
        self.path = path
    }

    func scann() throws -> [String: Path] {
        let srcExtensions = ["h", "m", "mm"]
        let srcs = try path.absolute().recursiveChildren()
            .filter {
                guard $0.isFile else {
                    return false
                }
                
                guard let `extension` = $0.extension, srcExtensions.contains(`extension`) else {
                    return false
                }
                
                let components = $0.components
                guard !components.contains("Pods") else {
                    return false
                }
                
                return true
            }
            .reduce(into: [String: Path]()) { $0[$1.lastComponent] = $1 }
        return srcs
    }
}
