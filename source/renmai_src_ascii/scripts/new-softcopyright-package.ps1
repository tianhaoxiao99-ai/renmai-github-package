param(
    [string]$OutputDir = ""
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $repoRoot "softcopyright-package"
}

$dirs = @(
    "01_申请表",
    "02_说明文档",
    "03_界面截图",
    "04_源程序",
    "05_补充材料"
)

foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir $dir) | Out-Null
}

$copyMap = @(
    @{ Source = "软著申请表填写稿.md"; Target = "01_申请表\软著申请表填写稿.md" },
    @{ Source = "软件设计说明书.md"; Target = "02_说明文档\软件设计说明书.md" },
    @{ Source = "使用说明书.md"; Target = "02_说明文档\使用说明书.md" },
    @{ Source = "softcopyright-output\renmai-web-source-bundle.txt"; Target = "04_源程序\renmai-web-source-bundle.txt" },
    @{ Source = "软著提交代码页选择建议.md"; Target = "04_源程序\软著提交代码页选择建议.md" },
    @{ Source = "软著申请材料检查清单.md"; Target = "05_补充材料\软著申请材料检查清单.md" },
    @{ Source = "软著截图清单.md"; Target = "05_补充材料\软著截图清单.md" },
    @{ Source = "软著最终提交包目录结构.md"; Target = "05_补充材料\软著最终提交包目录结构.md" }
)

foreach ($item in $copyMap) {
    $sourcePath = Join-Path $repoRoot $item.Source
    if (Test-Path -LiteralPath $sourcePath) {
        $targetPath = Join-Path $OutputDir $item.Target
        $targetParent = Split-Path -Parent $targetPath
        New-Item -ItemType Directory -Force -Path $targetParent | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    }
}

$readmePath = Join-Path $OutputDir "README_提交说明.txt"
$readme = @"
仁迈 V1.0.0 软著提交包

目录说明：
01_申请表      放申请表及填写稿
02_说明文档    放设计说明书、使用说明书
03_界面截图    放系统界面截图
04_源程序      放源码打印稿和代码页建议
05_补充材料    放检查清单和辅助说明

当前目录用于放置以下提交分区：
1. 申请表材料
2. 说明文档
3. 界面截图
4. 源程序材料
5. 补充说明材料

提交前核对并补充：
1. 正式申请表 PDF
2. 身份证明材料
3. 如有需要的签字页或盖章页
"@

$utf8 = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($readmePath, $readme, $utf8)

Write-Output "Generated package scaffold: $OutputDir"

