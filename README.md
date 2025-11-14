# CameraKit

CameraKit 是一个面向 Swift / SwiftUI 应用的拍摄与扫描组件，现在精简为两种体验：**拍摄 + 裁剪模式**（拍完立即进入裁剪器，输出编辑后的图片，可选回传原图）以及 **扫描模式**（调用 VisionKit 扫描，按页输出处理结果，可选回传原图）。开发者只需触发入口按钮并处理回调数据，即可获得自动矫正方向、可选等比缩放后的 `[UIImage]` 数组。

## 功能模块与可选性

| 模块 | 能力说明 | 是否可选 | 备注 |
| --- | --- | --- | --- |
| 相机权限 & 设备检查 | 自动请求 `NSCameraUsageDescription` 权限，并校验摄像头可用性。 | 否 | 必须同意权限才能进入拍摄界面。 |
| 拍摄 + 裁剪模式 | SwiftUI 全屏取景、拍照后进入可拖拽四角的裁剪器。 | 否 | 对单页凭证/卡证最友好，裁完图后才进入处理流程。 |
| 扫描模式 | 基于 `VNDocumentCamera` 的多页扫描导出。 | 否 | 适合发票、合同等多页文档。 |
| 图像增强 | 支持 `none` / `auto` / `grayscale`，提升可读性。 | 是 | 由 `enhancement` 参数控制。 |
| 相册导入（iOS） | 拍摄界面可打开相册，替换拍摄结果。 | 是 | 由 `allowsPhotoLibraryImport` 控制。 |
| Mac Catalyst 导入 | 无法直接拍摄时，自动提供“打开相册 / 文件夹”入口，并按相同流程处理图片。 | - | 所有模式均可用，保持输出一致。 |
| 结果回调 | 将本次操作产生的所有图片以 `[UIImage]` 形式回传，已统一方向与尺寸。 | 否 | 单次拍摄返回 1 张，扫描可返回多张。 |
| 国际化与文案 | 内建英文 + 简体中文，可拓展自定义语言。 | 是 | 添加新的 `.lproj` 资源即可。 |

## 配置项总览

| 配置项 | 作用 | 是否必填 | 默认值 / 建议 |
| --- | --- | --- | --- |
| `mode` | `.captureWithCrop`（拍后裁剪）或 `.scan`（文档扫描）。 | 必填 | 根据场景切换对应模式。 |
| `enhancement` | 输出增强策略：`.none` / `.auto` / `.grayscale`。 | 可选 | 默认 `.auto`。 |
| `allowsPhotoLibraryImport` | 是否在 iOS 拍摄界面提供相册入口。 | 可选 | 默认 `false`。 |
| `maxOutputWidth` | 限制处理后图片的最大宽度，按比例缩放高度。 | 可选 | 默认 `nil`，即保持原始尺寸。 |

> 说明：`maxOutputWidth` 仅在指定值 > 0 时生效，会将宽度缩放到目标值并保持原始纵横比。  
> Mac Catalyst 环境下，CameraKit 自动切换为“打开相册 / 文件夹”流程，仍然会走同样的裁剪/增强/缩放逻辑。

## 回调数据

- `onResult([UIImage])`：返回按照选择顺序处理好的所有图片（已校正方向，可选缩放宽度）。
- `onOriginalImageResult?([UIImage])`：可选回调。若传入该闭包，则会额外收到“未处理”的原始图片数组（顺序与 `onResult` 一致）；未提供闭包时则默认不回传原图，避免不必要的内存与带宽开销。
- `onCancel()`：用户主动关闭或返回。
- `onError(CameraKitError)`：包含 `permissionDenied`、`cameraUnavailable`、`captureFailed`、`processingFailed` 等类型，便于友好提示。

## 安装方式（Swift Package Manager）

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/your-org/CameraKit.git", branch: "main")
]
```

并在目标中引入：

```swift
.product(name: "CameraKit", package: "CameraKit")
```

## 快速使用示例

```swift
import CameraKit

struct ScanActionView: View {
    var body: some View {
        CameraKitLauncherButton(
            configuration: CameraKitConfiguration(
                mode: .scan,
                enhancement: .auto,
                allowsPhotoLibraryImport: true,
                maxOutputWidth: 2048
            ),
            onResult: { images in
                // 处理扫描结果，images 为自动矫正后的数组
            },
            onOriginalImageResult: { originals in
                // 如需保存/另行处理原图，在这里拿到同顺序的原始数组
            },
            onCancel: {
                // 关闭或返回后的兜底逻辑
            },
            onError: { error in
                // 根据 CameraKitError 展示提示
            }
        )
    }
}
```

若需要自定义按钮外观，可直接使用 `CameraKitLauncher` 并传入自定义 `label` 视图。

## 国际化

- 默认提供英文与简体中文资源，位于 `Sources/CameraKit/Resources/`。
- 若需扩展语言，在目标内新增相应 `.lproj/Localizable.strings` 并添加翻译，同时保持键值不变。

## 运行要求与权限

- Swift 6 工具链。
- iOS 13+ 或 macOS Catalyst 13+。
- 在宿主 App 的 `Info.plist` 中添加 `NSCameraUsageDescription`；若启用相册导入，再增加 `NSPhotoLibraryUsageDescription`。
- 需在 App 启动前确保已获取 Vision / AVFoundation 所需的权限声明。

## 测试

```bash
swift test
```

若在沙箱环境中拉取依赖失败，请根据提示授权或在本地再次执行。
