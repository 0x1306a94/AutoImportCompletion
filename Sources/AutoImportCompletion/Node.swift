//
//  File.swift
//
//
//  Created by king on 2022/4/25.
//

import Foundation

class Node {
    weak var parent: Node?
    private(set) var nodes: [Node]
    let content: String
    init(parent: Node? = nil, content: String, nodes: [Node] = []) {
        self.parent = parent
        self.content = content
        self.nodes = nodes
    }

//    deinit {
//        print("deinit:", self)
//    }
}

extension Node {
    func addDepend(node: Node) {
        if !self.nodes.contains(where: { $0.content == node.content }) {
            self.nodes.append(node)
        }
    }

    var depth: Int {
        if parent == nil {
            return 0
        }
        var level = 1
        var p = parent?.parent
        while p != nil {
            level += 1
            p = p?.parent
        }

        return level
    }

    subscript(depth: Int) -> [Node] {
        if self.nodes.isEmpty || self.depth == depth {
            return [self]
        }

        var allNodes: [Node] = []
        for node in self.nodes {
            let v = node[depth]
            allNodes.append(contentsOf: v)
        }
        return allNodes
    }

    func treePrint() {
        print("<-------------- \(self.content) -------------->")
        var printStack = self.nodes
        while !printStack.isEmpty {
            let node = printStack.removeFirst()
            let level = max(0, node.depth - 1)
            let tables = (0 ..< level).map { _ in "\t" }.joined(separator: "")
            print("\(tables)\(node.content)")
            if !node.nodes.isEmpty {
                printStack.insert(contentsOf: node.nodes, at: 0)
                continue
            }
        }
    }
}
