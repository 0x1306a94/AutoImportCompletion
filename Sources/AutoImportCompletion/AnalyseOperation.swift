//
//  AnalyseOperation.swift
//
//
//  Created by king on 2022/4/25.
//

import Foundation
import PathKit

class AnalyseOperation: Operation {
    private var _executing: Bool = false {
        // kvo isExecuting
        willSet {
            willChangeValue(forKey: ModifyState.isExecuting.rawValue)
        }
        didSet {
            didChangeValue(forKey: ModifyState.isExecuting.rawValue)
        }
    }

    private var _finished: Bool = false {
        // kvo isFinished
        willSet {
            willChangeValue(forKey: ModifyState.isFinished.rawValue)
        }
        didSet {
            didChangeValue(forKey: ModifyState.isFinished.rawValue)
        }
    }

    private enum ModifyState: String {
        case isExecuting
        case isFinished
    }

    override var isExecuting: Bool {
        return _executing
    }

    override var isFinished: Bool {
        return _finished
    }

    override var isAsynchronous: Bool {
        return true
    }

    let path: Path
    let srcMap: [String: Path]
    let modify: Bool
    let depth: Int
    let verbose: Bool
    init(path: Path, srcMap: [String: Path], modify: Bool, depth: Int, verbose: Bool = false) {
        self.path = path
        self.srcMap = srcMap
        self.modify = modify
        self.depth = depth
        self.verbose = verbose
    }

    override func start() {
        if isCancelled {
            done()
            return
        }

        _executing = true

        do {
            try startTask()
        } catch let e {
            print(e)
            exit(EXIT_FAILURE)
        }
    }

    override func cancel() {
        done()
    }

    private func done() {
        if _executing {
            _finished = true
            _executing = false
        }
    }

    private func startTask() throws {
        if self.isCancelled {
            self.done()
            return
        }

        let contents = try String(contentsOf: path.url)
        var depends = contents.components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: " \\", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.hasSuffix(".h") && !$0.contains("DerivedData") && !$0.contains(".framework") }
            .map { Path($0) }

        let root = Node(content: path.lastComponent)
        var stack: [Node] = [
            root,
        ]

//        let pattern = "^#import [\"|<](.*?)[>|\"]"
        let pattern = "^#import \"(.*?)\""
        let RE = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])

        var nodeMap: [String: Node] = [:]
        func createNode(parent: Node, content: String) -> Node {
            if let node = nodeMap[content] {
                return node
            }
            let node = Node(parent: parent, content: content)
            nodeMap[content] = node
            return node
        }

        var index = 0
        while index < depends.count {
            let item = depends[index]

            guard let parent = stack.popLast() else {
                break
            }
            let node = createNode(parent: parent, content: item.lastComponent)
            parent.addDepend(node: node)

            var childs: [(Node, Path)] = [(node, item)]

            while !childs.isEmpty {
                let child = childs.removeFirst()

                let contents = try String(contentsOf: child.1.url)
                let matchs = RE.matches(in: contents, options: .reportProgress, range: NSMakeRange(0, contents.count))

                guard !matchs.isEmpty else {
                    continue
                }

                let subParent = child.0

                for match in matchs {
                    guard match.numberOfRanges == 2 else {
                        continue
                    }
                    let range = match.range(at: 1)
                    let str = (contents as NSString).substring(with: range)
                    guard let srcPath = srcMap[str] else {
                        continue
                    }

                    if let removeIndex = depends.firstIndex(where: { $0.string.hasSuffix(str) }) {
                        depends.remove(at: removeIndex)
                    }

                    if nodeMap[str] != nil {
                        continue
                    }

                    let sub = createNode(parent: subParent, content: str)
                    subParent.addDepend(node: sub)

                    childs.append((sub, srcPath))
                }
            }

            stack.append(parent)
            index += 1
        }

        if self.modify {
            try self.apply(root: root)
        } else {
            root.treePrint()
            self.done()
        }
    }

    func apply(root: Node) throws {
        defer {
            self.done()
        }

        // 修改源文件
        let fileName = root.content.replacingOccurrences(of: ".d", with: ".m")
        let fileName2 = root.content.replacingOccurrences(of: ".d", with: ".mm")
        guard let src = (self.srcMap[fileName] ?? self.srcMap[fileName2]) else {
            return
        }

        var depends: [String] = []
        for node in root.nodes {
            if self.depth <= 1 {
                depends.append(node.content)
                continue
            }

            if node.nodes.isEmpty {
                depends.append(node.content)
                continue
            }

            let nodes = node[depth]
            depends.append(contentsOf: nodes.map { $0.content })
        }

        let pattern = "^#import \"(.*?)\""
        let RE = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
        let contents = try String(contentsOf: src.url)

        let matchs = RE.matches(in: contents, options: .reportProgress, range: NSMakeRange(0, contents.count))
        if matchs.isEmpty {
            return
        }

        var exists: [String] = []
        for match in matchs {
            guard match.numberOfRanges == 2 else {
                continue
            }
            let range = match.range(at: 1)
            let str = (contents as NSString).substring(with: range)
            exists.append(str)
        }

        let set1 = Set(depends)
        let set2 = Set(exists)
        let subtract = set1.subtracting(set2)
        guard !subtract.isEmpty else {
            return
        }

        var imports: [String] = [
            "\n",
            "#pragma mark - AutoImportCompletion generate beging",
        ]

        imports.append(contentsOf: subtract.map { "#import \"\($0)\"" }.sorted())
        imports.append("#pragma mark - AutoImportCompletion generate end")
        imports.append("\n")

        let appeded = imports.joined(separator: "\n")
        if self.verbose {
            print("----------------- \(src.lastComponent) ----------------- \(appeded)")
        }
        guard let range = matchs.last?.range, let copyed = (contents as NSString).mutableCopy() as? NSMutableString else {
            return
        }

        copyed.insert(appeded, at: range.location + range.length)
        try copyed.write(to: src.url, atomically: true, encoding: String.Encoding.utf8.rawValue)
    }
}
