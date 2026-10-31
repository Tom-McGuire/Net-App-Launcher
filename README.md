# Network Suite Launcher

A centralized desktop hub built in Flutter for managing, downloading, launching, and updating tools in the Network Suite. Also acts as the primary inventory interface for the cross-process Shared Device Identity Library (`shared_devices.db`).

---

## Features

1. **GitHub Releases Dynamic Discovery**:
   - Queries `https://api.github.com/repos/Tom-McGuire/{repo}/releases/latest`.
   - Only displays tools that have published public releases (or tools already installed locally).
   - Private or unreleased repositories (returning 404) are automatically hidden by default.
   - Developer View toggle available to inspect the full catalog.

2. **One-Click Download & Launch**:
   - Downloads platform binaries matching OS (`*_windows_x64.zip`, `*_macos.zip`, `*_linux_x64.tar.gz`).
   - Automatically unzips into `%LOCALAPPDATA%\NetworkSuite\apps\<app_id>\`.
   - Tracks installed versions in `%LOCALAPPDATA%\NetworkSuite\installed_apps.json`.
   - Launches apps in detached mode via `Process.start`.

3. **External Dependency Diagnostics**:
   - Checks host machine for external CLI binaries (e.g., `tshark` for TShark-Interface, `iperf3` for Net-Bench).
   - Displays status badges and winget remediation commands.

4. **Shared Device Identity Manager**:
   - Connected directly to `%LOCALAPPDATA%\NetworkSuite\shared_devices.db` (SQLite in WAL mode).
   - Permanent hardware identity keyed strictly by **MAC address**.
   - No volatile IP addresses stored (guaranteeing integrity across subnet changes and DHCP migrations).
   - Allows renaming devices at any point, with updates instantly reflected across all suite applications.
   - CSV & JSON import and export.

---

## Project Structure

```
net-app-launcher/
├── lib/
│   ├── core/                  # App theme (tokens from UI_AND_DESIGN_PRINCIPLES.md), constants
│   ├── data/
│   │   ├── repositories/      # Suite & device coordination
│   │   └── services/          # GitHub API, installer, runner, dependencies, registry, export
│   ├── domain/                # Data models (SuiteApp, ReleaseInfo, DependencyInfo)
│   ├── ui/
│   │   ├── view_models/       # MVVM State management (Provider)
│   │   └── views/             # 5-tier layout (Apps dashboard, Device manager table, Dialogs)
│   └── main.dart
├── specs/                     # Integration specifications for all suite apps
└── test/                      # Unit and widget test suite
```

---

## Standalone Resilience

Each application in the suite uses the shared library `network_suite_shared` located at `C:\Users\tommc\Projects\network_suite_shared`.
Even if this Launcher application is never installed or opened, any suite application can create, read, and write to `shared_devices.db` on its own.

---

## Security & Code Signing Notes

> **Note on Windows / macOS Security Prompts:**
> These tools are free and independent projects and are not yet code-signed with expensive commercial certificates:
>
> - **Windows**: If SmartScreen appears, click **"More info"** → **"Run anyway"**.
> - **macOS**: Right-click the `.app` file, select **Open**, and confirm the prompt (or run `xattr -c <AppName>.app` in Terminal).

