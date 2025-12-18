# 部署和集成指南

## 🚀 快速开始

### 1. 更新依赖包

运行以下命令安装所有新的依赖：

```bash
cd path/to/project
flutter pub get
```

### 2. 验证文件完整性

确保以下文件都已创建/修改：

**新增文件** ✨
```
✅ lib/services/qr_service.dart
✅ lib/screens/share_qr_screen.dart
✅ lib/screens/import_qr_screen.dart
✅ test/qr_service_test.dart
✅ QR_CODE_FEATURE.md
✅ QUICK_REFERENCE.md
✅ IMPLEMENTATION_SUMMARY.md
```

**修改文件** ✏️
```
✅ lib/screens/home_screen.dart
✅ lib/services/unit_service.dart
✅ pubspec.yaml
```

### 3. 运行单元测试

```bash
flutter test test/qr_service_test.dart
```

**预期输出**：
```
✓ Encode and decode standard unit
✓ Compress with suffix pattern (same prefix, different suffix)
✓ Capacity check
✓ Large dataset compression test

All tests passed! ✓
```

### 4. 编译和测试

#### 开发版本
```bash
flutter run
```

#### 发布 APK
```bash
flutter build apk --release
```

---

## 📋 检查清单

### 代码集成检查
- [ ] 所有 import 语句正确
- [ ] 没有编译错误
- [ ] 所有依赖都已安装
- [ ] 单元测试通过

### Android 配置检查
- [ ] 权限配置 (已完成)
  - `CAMERA`
  - `WRITE_EXTERNAL_STORAGE`
  - `READ_EXTERNAL_STORAGE`
  - `WRITE_CLIPBOARD`
- [ ] 最小 SDK 版本 >= 21
- [ ] 目标 SDK 版本 >= 33

### 功能测试检查
- [ ] **分享功能**
  - [ ] 长按单元能打开菜单
  - [ ] 选择"生成二维码"能进入分享界面
  - [ ] 显示二维码和单元信息
  - [ ] "保存到相册"能保存图片
  - [ ] 保存的图片包含二维码和标题

- [ ] **导入功能**
  - [ ] 右上角导入按钮能打开导入界面
  - [ ] 能实时扫描二维码
  - [ ] "从相册导入"能选择图片
  - [ ] 能识别二维码并导入
  - [ ] 导入的单元出现在首页

- [ ] **压缩算法**
  - [ ] 后四位规律的数据能压缩
  - [ ] 压缩后能正确解码
  - [ ] 大数据集也能成功导入

---

## 🔧 常见问题解决

### 构建失败

#### 错误：`package: image not found`
```bash
# 解决方案
flutter pub get
flutter clean
flutter pub get
```

#### 错误：`google_mlkit_barcode_scanning version conflict`
```bash
# 修改 pubspec.yaml
google_mlkit_barcode_scanning: ^0.8.0

# 然后运行
flutter pub get
```

### 运行时错误

#### 二维码显示为黑屏
```
检查项：
1. _qrData 是否为 null
2. 数据是否超过 QR 码容量
3. errorStateBuilder 的提示信息
```

#### 导入失败
```
检查项：
1. 二维码图片清晰度
2. 网络连接 (如果使用 ML Kit)
3. 版本号是否匹配
```

---

## 📱 测试场景

### 场景1：单用户分享-导入
```
设备A:
  1. 创建单元 "Device Batch A"
  2. 添加60条记录 (后四位递增)
  3. 长按生成二维码
  4. 保存到相册
  
设备B:
  1. 点击导入
  2. 从相册选择图片
  3. 成功导入单元
  4. 所有60条记录显示正确
```

### 场景2：多单元共享
```
1. 创建多个单元
2. 分别生成二维码
3. 共享给同事
4. 同事导入所有单元
```

### 场景3: 压缩效果验证
```
运行测试:
  flutter test test/qr_service_test.dart --verbose
  
查看输出:
  "Encoded size for 60 records: ~1680 bytes"
  "Encoded size for 100 records: ~2300 bytes"
```

---

## 🎨 UI 定制选项

### 修改分享界面样式

编辑 `share_qr_screen.dart`:

```dart
// 修改二维码颜色
QrImage(
  data: _qrData!,
  backgroundColor: Colors.white,
  // 前景色修改需要自定义 painter
)

// 修改标题样式
Text(
  '单元: ${widget.unit.name}',
  style: const TextStyle(
    color: Colors.black87,      // 修改文字颜色
    fontSize: 24,               // 修改字体大小
    fontWeight: FontWeight.w600,
  ),
)

// 修改保存按钮
ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFF007AFF),  // 修改按钮颜色
  // ...
)
```

### 修改导入界面样式

编辑 `import_qr_screen.dart`:

```dart
// 修改扫描框颜色
final borderPaint = Paint()
  ..color = Colors.white          // 修改边框颜色
  ..style = PaintingStyle.stroke
  ..strokeWidth = 3;

// 修改遮罩颜色
final overlayPaint = Paint()
  ..color = const Color(0x88000000);  // 修改遮罩透明度
```

---

## 📊 性能优化建议

### 内存优化
```dart
// 在 dispose 中清理资源
@override
void dispose() {
  _controller?.dispose();
  super.dispose();
}
```

### 大数据处理
```dart
// 如果记录超过100条，考虑分页导出
if (records.length > 100) {
  // 提示用户考虑分割成多个单元
}
```

### 图片处理
```dart
// 保存大图片时考虑压缩
final result = await ImageGallerySaver.saveImage(
  byteData.buffer.asUint8List(),
  quality: 85,  // 调整质量 (0-100)
);
```

---

## 🔐 安全建议

### 数据保护
1. **备份重要单元**：建议定期导出二维码
2. **验证来源**：导入前检查单元信息
3. **权限管理**：仅授予必要权限

### 隐私考虑
1. **不存储敏感信息**：QR 码可被他人读取
2. **可选加密**：考虑添加 AES 加密（未实现）
3. **过期处理**：定期清理过期二维码图片

---

## 📈 监控和日志

### 添加日志追踪

在 `qr_service.dart` 中：
```dart
import 'dart:developer' as developer;

developer.log('Encoding unit: ${unit.name}');
developer.log('Encoded size: ${encoded.length} bytes');
```

### 错误追踪

在应用级别添加：
```dart
void main() {
  runApp(
    ChangeNotifierProvider(...),
    // 可以添加 Firebase Crashlytics 等
  );
}
```

---

## 🚀 发布前清单

### 代码审查
- [ ] 所有代码遵循 Flutter 最佳实践
- [ ] 注释完整，易于维护
- [ ] 没有 TODO 或 FIXME 标记
- [ ] 代码格式化正确 (`flutter format`)

### 功能验收
- [ ] 所有功能按需求实现
- [ ] 没有已知 bug
- [ ] 性能满足要求
- [ ] 用户体验流畅

### 文档完成
- [ ] 功能文档齐全
- [ ] API 文档完整
- [ ] 用户指南清晰
- [ ] 部署文档明确

### 构建和签名
- [ ] 版本号正确
- [ ] 签名密钥已备份
- [ ] 发布说明已准备
- [ ] 更新日志已记录

---

## 📞 支持和反馈

### 已知限制
1. **二维码容量**：最多支持 ~120 条记录
2. **网络依赖**：ML Kit 可能需要网络
3. **兼容性**：部分低端设备可能识别困难

### 未来改进
1. 添加数据加密选项
2. 支持批量导出/导入
3. 添加云端备份功能
4. 自定义 QR 码样式

---

## 📚 相关资源

### 官方文档
- [Flutter QR Flutter](https://pub.dev/packages/qr_flutter)
- [Google ML Kit](https://pub.dev/packages/google_mlkit_barcode_scanning)
- [Image Gallery Saver](https://pub.dev/packages/image_gallery_saver)

### QR 码标准
- [ISO/IEC 18004:2015](https://www.iso.org/standard/62021.html)
- [QR Code 最高版本：Version 40 (177×177 模块)](https://www.qrcode.com/en/about/standards.html)

---

**部署状态**：✅ **就绪** | **最后检查**：2025年12月
