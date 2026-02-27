## ios 运行

> [!CAUTION]
> **iOS 26 真机严禁使用 Debug 模式运行！**
> 由于 iOS 26 内存保护限制，Debug 模式会触发 EXC_BAD_ACCESS 崩溃。
> 调试真机请务必使用 `--profile` 或 `--release`。

```bash
fvm flutter run -d  00008140-000E38D81493001C --profile
```

## mac 运行

```bash
swiftc -o  VocalHost  mac/VocalHostApp.swift  -parse-as-library && ./VocalHost
```
