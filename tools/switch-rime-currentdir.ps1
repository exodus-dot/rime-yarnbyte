$ErrorActionPreference = "Stop"

# 自动使用本脚本所在目录，不写死任何盘符或路径
$BaseDir = $PSScriptRoot

# 当前 Windows 用户的 Rime 用户目录
$RimeHome = Join-Path $env:APPDATA "Rime"

function Invoke-RimeDeploy {
    Write-Host ""
    Write-Host "正在尝试重新部署小狼毫..." -ForegroundColor Yellow

    $candidates = @()

    # 尝试从注册表取安装目录
    foreach ($reg in @(
        "HKCU:\Software\Rime\Weasel",
        "HKLM:\SOFTWARE\Rime\Weasel",
        "HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel"
    )) {
        if (Test-Path $reg) {
            $p = Get-ItemProperty $reg -ErrorAction SilentlyContinue
            foreach ($name in @("WeaselRoot", "InstallDir", "InstallPath")) {
                if ($p.PSObject.Properties.Name -contains $name) {
                    $v = $p.$name
                    if ($v) {
                        $candidates += (Join-Path $v "WeaselDeployer.exe")
                    }
                }
            }
        }
    }

    # 尝试常见安装位置
    foreach ($root in @(
        "$env:ProgramFiles\Rime",
        "${env:ProgramFiles(x86)}\Rime"
    )) {
        if ($root -and (Test-Path -LiteralPath $root)) {
            $found = Get-ChildItem -LiteralPath $root -Filter "WeaselDeployer.exe" -File -Recurse -ErrorAction SilentlyContinue |
                     Select-Object -ExpandProperty FullName
            if ($found) { $candidates += $found }
        }
    }

    $deployer = $candidates |
        Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
        Select-Object -First 1

    if (-not $deployer) {
        Write-Host "没有找到 WeaselDeployer.exe；配置已切换，请手动“重新部署”。" -ForegroundColor Yellow
        return
    }

    Write-Host "部署器: $deployer" -ForegroundColor DarkGray
    Start-Process -FilePath $deployer -ArgumentList "/deploy" -WorkingDirectory (Split-Path $deployer) -Wait
    Write-Host "重新部署完成。" -ForegroundColor Green
}

try {
    Write-Host ""
    Write-Host "=== Rime 配置切换器 ===" -ForegroundColor Cyan
    Write-Host "配置根目录: $BaseDir"
    Write-Host "Rime 用户目录: $RimeHome"
    Write-Host ""

    # 扫描脚本所在目录下的一级子文件夹
    $dirs = @(Get-ChildItem -LiteralPath $BaseDir -Directory | Sort-Object Name)

    if ($dirs.Count -eq 0) {
        throw "当前脚本目录下没有找到任何配置文件夹。"
    }

    # 获取当前 Junction 的目标（若存在）
    $currentTarget = $null
    if (Test-Path -LiteralPath $RimeHome) {
        $item = Get-Item -LiteralPath $RimeHome -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            try {
                $currentTarget = $item.Target
                if ($currentTarget -is [array]) {
                    $currentTarget = $currentTarget[0]
                }
            } catch {}
        }
    }

    Write-Host "请选择要启用的 Rime 配置：" -ForegroundColor Yellow
    for ($i = 0; $i -lt $dirs.Count; $i++) {
        $mark = " "
        if ($currentTarget) {
            try {
                $a = [IO.Path]::GetFullPath($dirs[$i].FullName).TrimEnd('\')
                $b = [IO.Path]::GetFullPath([string]$currentTarget).TrimEnd('\')
                if ($a -ieq $b) { $mark = "*" }
            } catch {}
        }
        Write-Host (" {0} [{1}] {2}" -f $mark, ($i + 1), $dirs[$i].Name)
    }

    if ($currentTarget) {
        Write-Host ""
        Write-Host "* = 当前配置" -ForegroundColor DarkGray
    }

    Write-Host ""
    $choice = Read-Host "输入编号"

    $index = 0
    if (-not [int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $dirs.Count) {
        throw "无效选择：$choice"
    }

    $target = $dirs[$index - 1].FullName

    Write-Host ""
    Write-Host "准备切换到: $target" -ForegroundColor Cyan

    if (Test-Path -LiteralPath $RimeHome) {
        $item = Get-Item -LiteralPath $RimeHome -Force

        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Write-Host "移除当前 Rime Junction..." -ForegroundColor DarkYellow
            & cmd.exe /d /c rmdir "`"$RimeHome`""
            if ($LASTEXITCODE -ne 0) {
                throw "无法移除当前 Rime Junction。"
            }
        }
        else {
            # 如果是真实目录，不直接删除，先备份
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $backup = "$RimeHome.backup-$timestamp"
            Write-Host "当前 Rime 是真实目录，自动备份到：" -ForegroundColor Yellow
            Write-Host "  $backup" -ForegroundColor Yellow
            Move-Item -LiteralPath $RimeHome -Destination $backup
        }
    }

    Write-Host "创建 Junction..." -ForegroundColor DarkYellow
    & cmd.exe /d /c mklink /J "`"$RimeHome`"" "`"$target`""

    if ($LASTEXITCODE -ne 0) {
        throw "创建 Junction 失败。"
    }

    Write-Host ""
    Write-Host "切换成功：" -ForegroundColor Green
    Write-Host "  $RimeHome"
    Write-Host "    => $target"

    Invoke-RimeDeploy
}
catch {
    Write-Host ""
    Write-Host ("错误: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

Write-Host ""
Read-Host "按 Enter 退出"
