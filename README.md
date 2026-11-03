# ChimeraTool 安装器分析

对 ChimeraTool（Euroserver s.r.o.，chimeratool.com）两个 Windows 安装器样本的静态与动态分析。

## 样本

- `ChimeraInstaller.exe` — 主程序安装包（WinLicense/Themida + PyInstaller 双层）
- `ChimeraTool_Authenticator_Driver.exe` — 授权驱动安装器（Indigo Rose Setup Factory 9.5）

原始 EXE 以 Release 附件分发：`releases/download/samples/`

## 快速结论

| 项目 | 结果 |
|---|---|
| 主安装器保护 | `.winlice` + `.boot` 节区 → WinLicense/Themida |
| 主安装器内层 | PyInstaller 3.13，运行时释放 `_MEI*` 目录 356 文件 |
| 驱动安装器封装 | Setup Factory 9.5，10.7 MB 加密 overlay |
| 驱动安装引擎 | `irsetup.exe`（UPX，1.39MB → 3.82MB）+ `lua5.1.dll` |
| 驱动安装能力 | 已确认 `InstallDriver`/`SQLInstallDriverEx`/`CreateServiceA` |
| GUI 自动化 | 已推进主安装器至语言/EULA 页 |
| 签名主体 | Euro-Server s.r.o.（DigiCert / Starfield 证书） |

完整记录见 **[`analysis/FINDINGS.md`](analysis/FINDINGS.md)**。

## 目录

```
analysis/FINDINGS.md          全部实验记录、成功/失败项、下一步路径
scripts/drive.ps1             UI 自动驱动（窗口签名 + 网格点击）
scripts/silent.ps1            静默开关探测
scripts/snatch.ps1            %TEMP% 快照抓取
.github/workflows/drive3.yml  当前最完整工作流（10 step 全通过）
.github/workflows/unpack.yml  首次解包捕获
.github/workflows/diag.yml    诊断（进程/退出码/7z）
```

## 免责

本仓库用于互操作性与安全研究。样本为第三方商业软件，版权归 Euroserver s.r.o. 所有。未修改或再分发程序本体。
