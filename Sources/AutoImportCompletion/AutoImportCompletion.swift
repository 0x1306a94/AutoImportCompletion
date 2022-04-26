import ArgumentParser
import Foundation
import PathKit

@main
struct AutoImportCompletion: ParsableCommand {
    @Argument(help: ".d 文件目录")
    var depend: String
    
    @Argument(help: "源码目录")
    var src: String
    
    @Option(name: .shortAndLong, help: "正则表达式")
    var excludePattern: [String] = []
    
    @Option(name: .shortAndLong, help: "深度, 默认为 1")
    var depth: Int = 1
    
    @Flag(name: .shortAndLong, help: "直接修改")
    var modify = false
    
    @Flag(help: "输出日志")
    var verbose = false
    
    func validate() throws {
        if depend.isEmpty {
            throw AutoImportCompletionError.pathEmpty(depend)
        }
        
        if src.isEmpty {
            throw AutoImportCompletionError.pathEmpty(src)
        }
        
        let dependPath = Path(depend)
        guard dependPath.isDirectory else {
            throw AutoImportCompletionError.pathNotDirectory(depend)
        }
        
        let srcPath = Path(depend)
        guard srcPath.isDirectory else {
            throw AutoImportCompletionError.pathNotDirectory(src)
        }
    }
    
    mutating func run() throws {
        let path = Path(depend)
        guard path.isDirectory else {
            throw AutoImportCompletionError.fileNotFound(depend)
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        
        let scanner = SourceScanner(path: Path(src))
        let srcMap = try scanner.scann()
        
        let queue = OperationQueue()
        queue.name = "AutoImportCompletion"
        queue.maxConcurrentOperationCount = ProcessInfo.processInfo.processorCount
        
        var paths = path.glob("*.d")
        
        excludePattern = excludePattern.filter { !$0.isEmpty }
        if !excludePattern.isEmpty {
            let RES = try excludePattern.map { try NSRegularExpression(pattern: $0, options: [.caseInsensitive, .anchorsMatchLines]) }
            paths = paths.filter {
                let str = $0.string
                for RE in RES {
                    let matchs = RE.matches(in: str, options: .reportProgress, range: NSMakeRange(0, str.count))
                    guard matchs.isEmpty else {
                        return false
                    }
                }
                return true
            }
        }
        
        let count = paths.count
        paths.forEach {
            let op = AnalyseOperation(path: $0, srcMap: srcMap, modify: modify, depth: depth, verbose: verbose)
            queue.addOperation(op)
        }
        queue.waitUntilAllOperationsAreFinished()
        if verbose {
            print("count: \(count) elapsed time: \(String(format: "%.02fs", CFAbsoluteTimeGetCurrent() - start))")
        }
    }
}
