# AutoImportCompletion

A description of this package.

##### build

```shell
git clone git@github.com:0x1306a94/AutoImportCompletion.git
cd AutoImportCompletion
swift build
.build/debug/auto-import-completion

# release .
swift build -c release
.build/release/auto-import-completion

# universal
swift build -c release --arch arm64 --arch x86_64
.build/apple/Products/Release/auto-import-completion
```

#### 使用
* 先用`Xcode`编译一次项目,在编译日志里面随便找个主项目的编译日志 找到 `.d` 文件目录, 编译参数 `-MF` 后面就是 `.d` 文件
* 然后执行分析 
```shell
.build/apple/Products/Release/auto-import-completion -e ".*TUI" -e ".*TIM.*" -d 3 .d文件目录 源码目录 -e ".*MachOSignature.*" -e ".*Samples.*" -e ".*main.*" -e ".*JavascriptBridge.*"
```
