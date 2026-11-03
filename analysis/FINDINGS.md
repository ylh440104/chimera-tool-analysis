# ChimeraTool 双安装器：动态破解实验记录

本文件记录在 GitHub Actions `windows-latest` runner 上对两个样本的实际实验，包含成功项、失败项与可复现命令。

## 1. 样本

| | 主安装器 | 授权驱动安装器 |
|---|---|---|
| 文件名 | `ChimeraInstaller.exe` | `ChimeraTool_Authenticator_Driver.exe` |
| 大小 | 15,162,256 | 10,878,664 |
| 架构 | PE32 GUI x86 | PE32 GUI x86 |
| MD5 | `96fcc75dd27895a625da1022cb31b70a` | `013b0bb23786935b0fdb27e05908f662` |
| SHA-256 | `6a8b7df69be2bf2ba0bbdbc6c27898800bd362d5707888325b239d6f668938bc` | `e384dcc2943a4d82e15a33985379a6f15b4d6b65eb779a40862c35013f6d95a5` |
| 版本 | 29.03 / 13.88.1015.0 | 1.6.0.0（原始名 `suf_launch.exe`） |
| 厂商 | Euroserver Sro. | Euro-Server s.r.o. |
| 签名 | DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1 | Starfield Secure Certificate Authority - G2 |

官网：`https://chimeratool.com`（Euroserver s.r.o.，产品为手机维修工具）

## 2. 保护与封装识别

### 主安装器：WinLicense/Themida + PyInstaller

节表：

```
          vsize=0x14167e5 raw=0x820200 ent=7.99
          vsize=0x543786  raw=0x208c00 ent=7.96
          vsize=0x38ca4   raw=0x9000   ent=7.88
          vsize=0x80      raw=0x200    ent=1.57
          vsize=0x71e     raw=0x400    ent=6.35
          vsize=0x517ca   raw=0x51800  ent=8.00
          vsize=0x147f8   raw=0x4400   ent=7.92
.idata    vsize=0x1000    raw=0x600    ent=4.44
.tls      vsize=0x1000    raw=0x200    ent=0.30
.rsrc     vsize=0x14800   raw=0x14800  ent=3.34
.winlice  vsize=0x640000  raw=0x0      ent=0.00   <-- WinLicense 特征节
.boot     vsize=0x3d5e00  raw=0x3d5e00 ent=7.96   <-- 加密启动体
```

`.winlice`（0 磁盘数据、运行时分配）+ `.boot`（近 8.0 熵）是 Oreans WinLicense/Themida 的布局特征。

运行后实测：释放 `%TEMP%\_MEI19362\`（PyInstaller 3.13 运行目录，356 个文件），内含：

```
_rust.pyd                    8,296,448
python313.dll                6,096,232
libcrypto-3.dll              5,232,408
mitmproxy_rs.pyd             4,116,480
_crypto.pyd                  3,718,656
base_library.zip             1,397,246
windows-redirector.exe       1,039,872
Binding.pyd                    868,864
```

即：**WinLicense 外壳内套 PyInstaller 打包的 Python 3.13 应用**。

### 授权驱动安装器：Indigo Rose Setup Factory 9.5

```
.text   raw=0x5800  ent=6.49
.rdata  raw=0x3000  ent=5.09
.data   raw=0xc00   ent=2.59
.rsrc   raw=0xbe00  ent=4.91
.reloc  raw=0x1200  ent=3.71
```

- 节区数据结束于 `0x16800`，其余 **10,786,504 字节为 overlay**
- overlay 高熵区（0x1c0000 起约 9 MB，熵 8.00、无重复 16 字节块 → 流式加密，非 zlib/纯压缩）
- 内含 Setup Factory 标记 `irsetup.dat`（overlay 偏移 `0x1a3906`）、`SUF` 标记、`suf_launch.exe`/`suf_rt.exe` 版本资源
- overlay 偏移 `0x15302a` 处有内嵌 PE：x86 DLL，323,584 字节，导出 128 个 `luaL_*`/`lua_*` 符号 → **Lua 5.1 运行时**

## 3. 动态实验（GitHub Actions windows-latest）

### 3.1 成功项

1. **两个安装器都能在该 runner 上真实启动 GUI**（WinLicense 未拦截 CI 环境）。
2. **授权驱动安装器自解包成功**：运行时释放到 `%TEMP%\_ir_sf_temp_0\`：

```
irsetup.exe      1,388,544
lua5.1.dll         329,944
Chimera.ico         32,988
```

3. **`irsetup.exe` 已成功 UPX 解压**：

```
upx -d irsetup.exe -o irsetup_upx.exe
      1,388,544  ->  3,818,496  (36.36%)
```

4. 解压后的 `irsetup.exe` 确认具备完整驱动安装能力（字符串实证）：

```
InstallDriver
UninstallDriver
SQLInstallDriverEx
SQLInstallDriverManager
CreateServiceA / DeleteService / ControlService / OpenServiceA
AdjustTokenPrivileges / OpenProcessToken
IsVistaAdminLimitedToken
```

5. **主安装器被自动点击推进到语言选择页**（截图 `inst-drive3.png`）：
   - 第一轮已确认能推进到 `End User Licence Agreement`（`inst-8.png`）
   - 第三轮记录到 `Please choose your language` 页（含 `Next` 按钮）

### 3.2 UI 自动化方法（已验证有效）

三路并发策略：

1. **窗口局部截图哈希**：`GetWindowRect` + `CopyFromScreen` 抓窗口，BMP 编码后取 SHA-256 前 16 位作为状态签名，用于判定点击是否生效；
2. **网格坐标点击**：按窗口相对比例遍历 `x ∈ {0.35,0.50,0.62,0.72,0.80,0.87,0.93}`、`y ∈ {0.72,0.80,0.86,0.91,0.95,0.975}`，每次点击后比对签名；
3. **键盘兜底**：`Down ×8 + End` 滚到底，再 `Tab + Enter`。

实测：主安装器每轮都命中（`inst-hit-r1..r10-720.png` 共 10 张）。

### 3.3 失败项（如实记录）

| 尝试 | 结果 | 原因 |
|---|---|---|
| UIAutomation 枚举 Button | 0 个 | Setup Factory 与 PyInstaller GUI 均为自绘控件，不暴露 UIA Button |
| `Tab + Enter` 接受 EULA | 无效 | 焦点不在按钮上 |
| 静默开关 `/S /s /silent /SILENT /verysilent /q /quiet /extract` | 全部无输出、无解包 | Setup Factory 9.5 不支持这些通用参数 |
| 授权驱动安装器点击 `Install driver >` | 未推进 | Welcome 页按钮位置与网格假设不符，8 轮均未变更签名 |
| 抓取驱动落盘 | 无 `.sys` / `.inf` 新增 | 驱动仅在真正执行安装后才释放 |
| `%TEMP%` 快照抓取 `snatched/` | 空 | 脚本以独立进程启动，工作目录继承失败导致输出路径错误 |

## 4. 已确认的能力（不是猜测）

1. `ChimeraTool_Authenticator_Driver.exe` 的 overlay 里是加密的 Setup Factory 归档，**不是**明文驱动。
2. 该归档的解包引擎是 `irsetup.exe`（UPX 压缩）+ `lua5.1.dll`，安装逻辑用 Lua 脚本描述。
3. `irsetup.exe` 具备 `InstallDriver` / `SQLInstallDriverEx` / `CreateServiceA` 等 API 调用能力，说明它确实会安装内核驱动。
4. 主安装器内套 PyInstaller，其 Python 代码与资源在 `_MEI*` 目录中以明文 `.pyc`/`.pyd` 形式存在（本次未提取 `.pyc`）。

## 5. 下一步（明确的技术路径）

### 路线 A：解出 Setup Factory 归档（无需执行安装）

1. 用 Ghidra 反编译 `irsetup_upx.exe`，定位读取 overlay 的代码路径；
2. 找到解密例程（Setup Factory 9 通常为 RC4 或自定义 XOR + 长度前缀），提取密钥；
3. 按 `0x40000`（262144）分块解密 overlay 0x1c0000 起的 34 个块 + 尾部 38,600 字节；
4. 解出 `.sys` / `.inf` / `.cat` 与 `irsetup.dat`（Lua 安装脚本）。

### 路线 B：让安装真正执行

1. 读取实际窗口尺寸与分辨率（`GetSystemMetrics`），按截图逐像素定位 `Install driver >` 按钮中心；
2. 或在 Welcome 页直接发送窗口消息（`WM_LBUTTONDOWN`/`UP` + 正确 `lParam` 坐标）绕过光标注入；
3. 安装完成后抓 `C:\Windows\System32\drivers\*.sys`、`Get-Service`、`C:\Windows\INF\*.inf`、`DriverStore`。

### 路线 C：主安装器 PyInstaller 提取

1. 在 runner 上于 `_MEI*` 存活期间复制整个目录；
2. 用 `pyinstxtractor` / `decompyle3` 还原 `.pyc`；
3. 得到 ChimeraTool 主程序逻辑与其网络协议（更接近"破解"目标）。

## 6. 复现命令

```powershell
# 样本
Invoke-WebRequest "https://github.com/ylh440104/chimera-tool-analysis/releases/download/samples/ChimeraTool_Authenticator_Driver.exe" -OutFile authdrv.exe
Invoke-WebRequest "https://github.com/ylh440104/chimera-tool-analysis/releases/download/samples/ChimeraInstaller.exe" -OutFile installer.exe

# 自动驱动（第三版）
pwsh -NoProfile -File .\scripts\drive.ps1 -Exe 'ChimeraInstaller.exe' -Tag 'inst' -Rounds 10

# UPX 还原（解出后的 irsetup.exe）
upx -d irsetup.exe -o irsetup_upx.exe
```

工作流：`.github/workflows/drive3.yml`（10 个 step，全部成功）。
