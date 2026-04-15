#!/usr/bin/env python3
from __future__ import annotations

import html
import json
import math
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
OUTPUT_ROOT = ROOT / "softcopyright-output"
GENERATED_ROOT = OUTPUT_ROOT / "generated"
HTML_ROOT = GENERATED_ROOT / "html"
PDF_ROOT = GENERATED_ROOT / "pdf"
SCREENSHOT_ROOT = GENERATED_ROOT / "screenshots"
AUTOMATION_ROOT = OUTPUT_ROOT / "automation"
PACKAGE_ROOT = ROOT / "softcopyright-package"
HEADLESS_WORK_ROOT = Path(r"C:\Users\Administrator\.codex\memories") / "softcopyright-headless"

STORAGE_KEY = "renmai-web-prototype-v3"
AUTH_STORAGE_KEY = "renmai-web-auth-v1"
AUTH_SESSION_KEY = "renmai-web-auth-session-v1"
PUBLIC_AUTH_FLOW_STORAGE_KEY = "renmai-public-auth-flow-v1"
LOCAL_REGISTER_FLOW_KEY = "renmai-local-register-flow-v1"
SECRET_STORAGE_KEY = "renmai-web-secret-settings-v1"
GEO_STORAGE_KEY = "renmai-web-geo-cache-v1"

DEFAULT_AUTH_STATE = {
    "users": [
        {
            "id": "auth-demo-user",
            "name": "演示访客",
            "identifier": "demo@renmai.app",
            "password": "demo123456",
            "role": "本地体验账号",
        }
    ],
    "ui": {
        "mode": "welcome",
        "feedback": "",
        "feedbackType": "",
        "lastIdentifier": "demo@renmai.app",
    },
}

DEFAULT_AUTH_SESSION = {
    "currentUserId": "auth-demo-user",
    "remember": True,
}

PORTRAIT_RELATIONSHIP = {
    "id": "rel-1",
    "name": "林然",
    "type": "friend",
    "city": "上海",
    "birthday": "04-08",
    "weeklyFrequency": 4,
    "monthlyDepth": 3,
    "importanceTier": "important",
    "importanceRank": 3,
    "lastContact": "2026-03-12",
    "note": "最近在聊副业合作，适合约一次线下见面把合作边界聊清楚。",
    "tags": ["大学同学", "合作中"],
    "portraitProfile": {
        "appearanceLabel": "清爽松弛型",
        "summary": "整体气质偏清爽松弛，适合用轻松直接的方式推进关系和合作话题。",
        "source": "local",
        "analyzedAt": "2026-03-18",
        "styleTags": ["自然感", "低压力沟通", "简洁穿搭", "合作友好"],
        "communicationHints": [
            "适合先给结论，再补背景。",
            "讨论合作时尽量把边界和节奏说清楚。",
        ],
        "giftHints": ["优先选择轻量、实用、有设计感的小礼物。"],
        "traitTags": ["理性", "直接", "重边界"],
    },
}


DOCUMENT_SPECS = [
    {
        "slug": "software-design-spec",
        "source": ROOT / "软件设计说明书.md",
        "title": "仁迈 V1.0.0 软件设计说明书",
        "package_target": PACKAGE_ROOT / "02_说明文档" / "软件设计说明书.pdf",
    },
    {
        "slug": "user-guide",
        "source": ROOT / "使用说明书.md",
        "title": "仁迈 V1.0.0 使用说明书",
        "package_target": PACKAGE_ROOT / "02_说明文档" / "使用说明书.pdf",
    },
    {
        "slug": "application-draft-reference",
        "source": ROOT / "软著申请表填写稿.md",
        "title": "仁迈 V1.0.0 软著申请表填写稿（参考）",
        "package_target": PACKAGE_ROOT / "01_申请表" / "软著申请表填写稿_参考.pdf",
    },
]

SCREENSHOT_SPECS = [
    {
        "slug": "01-welcome-login",
        "filename": "01_欢迎登录页.png",
        "target": "/index.html",
        "auth_state": {
            "ui": {
                "mode": "welcome",
                "lastIdentifier": "demo@renmai.app",
            }
        },
        "window_size": (1600, 1900),
    },
    {
        "slug": "02-register",
        "filename": "02_注册页.png",
        "target": "/index.html",
        "auth_state": {
            "ui": {
                "mode": "register",
                "lastIdentifier": "tiaohaoxiao99@gmail.com",
            }
        },
        "window_size": (1600, 1900),
    },
    {
        "slug": "03-reset-request",
        "filename": "03_找回密码页.png",
        "target": "/index.html",
        "auth_state": {
            "ui": {
                "mode": "reset-request",
                "lastIdentifier": "tiaohaoxiao99@gmail.com",
            }
        },
        "window_size": (1600, 1900),
    },
    {
        "slug": "04-dashboard",
        "filename": "04_首页总览页.png",
        "target": "/index.html?resume=1#dashboard",
        "auth_state": DEFAULT_AUTH_STATE,
        "auth_session": DEFAULT_AUTH_SESSION,
        "window_size": (1680, 2200),
    },
    {
        "slug": "05-relationship-list",
        "filename": "05_关系列表页.png",
        "target": "/index.html?resume=1#relationships",
        "auth_state": DEFAULT_AUTH_STATE,
        "auth_session": DEFAULT_AUTH_SESSION,
        "app_state": {
            "ui": {
                "activePage": "relationships",
                "relationView": "list",
                "selectedRelationshipId": "rel-1",
            }
        },
        "window_size": (1680, 2200),
    },
    {
        "slug": "06-relationship-graph",
        "filename": "06_关系图谱页.png",
        "target": "/index.html?resume=1#relationships",
        "auth_state": DEFAULT_AUTH_STATE,
        "auth_session": DEFAULT_AUTH_SESSION,
        "app_state": {
            "ui": {
                "activePage": "relationships",
                "relationView": "graph",
                "selectedRelationshipId": "rel-1",
            }
        },
        "window_size": (1680, 2200),
    },
    {
        "slug": "07-analysis",
        "filename": "07_AI分析页.png",
        "target": "/index.html?resume=1#analysis",
        "auth_state": DEFAULT_AUTH_STATE,
        "auth_session": DEFAULT_AUTH_SESSION,
        "app_state": {
            "ui": {
                "activePage": "analysis",
                "selectedAnalysisId": "analysis-seed-1",
            }
        },
        "window_size": (1680, 2200),
    },
    {
        "slug": "08-portrait-profile",
        "filename": "08_画像档案页.png",
        "target": "/index.html?resume=1#messages",
        "auth_state": DEFAULT_AUTH_STATE,
        "auth_session": DEFAULT_AUTH_SESSION,
        "app_state": {
            "relationships": [PORTRAIT_RELATIONSHIP],
            "manualMessages": [
                {
                    "id": "manual-1",
                    "relationshipId": "rel-1",
                    "role": "me",
                    "text": "这周找个时间把合作边界再对齐一下，我周四晚上有空。",
                    "meta": "微信",
                    "createdAt": "2026-03-17",
                },
                {
                    "id": "manual-2",
                    "relationshipId": "rel-1",
                    "role": "other",
                    "text": "可以，我这周五下午之后比较稳，地点你定就行。",
                    "meta": "微信",
                    "createdAt": "2026-03-17",
                },
            ],
            "ui": {
                "activePage": "messages",
                "selectedRelationshipId": "rel-1",
                "selectedMessageRelationshipId": "rel-1",
            },
        },
        "window_size": (1680, 2200),
    },
    {
        "slug": "09-gift-recommendations",
        "filename": "09_礼物推荐页.png",
        "target": "/index.html?resume=1#gifts",
        "auth_state": DEFAULT_AUTH_STATE,
        "auth_session": DEFAULT_AUTH_SESSION,
        "app_state": {
            "ui": {
                "activePage": "gifts",
                "selectedGiftRelationshipId": "rel-5",
                "giftRelation": "partner",
                "giftOccasion": "纪念日",
                "giftBudget": 520,
            }
        },
        "window_size": (1680, 2200),
    },
    {
        "slug": "10-messages",
        "filename": "10_消息页.png",
        "target": "/index.html?resume=1#messages",
        "auth_state": DEFAULT_AUTH_STATE,
        "auth_session": DEFAULT_AUTH_SESSION,
        "app_state": {
            "ui": {
                "activePage": "messages",
                "selectedRelationshipId": "rel-1",
                "selectedMessageRelationshipId": "rel-1",
            }
        },
        "window_size": (1680, 2200),
    },
    {
        "slug": "11-profile",
        "filename": "11_我的设置页.png",
        "target": "/index.html?resume=1#profile",
        "auth_state": DEFAULT_AUTH_STATE,
        "auth_session": DEFAULT_AUTH_SESSION,
        "app_state": {
            "ui": {
                "activePage": "profile",
            }
        },
        "window_size": (1680, 2200),
    },
]


class SilentHandler(SimpleHTTPRequestHandler):
    def log_message(self, format: str, *args: object) -> None:
        return


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def read_text(path: Path) -> str:
    for encoding in ("utf-8-sig", "utf-8", "gb18030", "utf-16"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError("utf-8", b"", 0, 1, f"Unable to decode {path}")


def write_text(path: Path, content: str) -> None:
    ensure_dir(path.parent)
    path.write_text(content, encoding="utf-8-sig")


def html_document(title: str, body: str, extra_css: str = "") -> str:
    return f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <style>
    @page {{
      size: A4;
      margin: 16mm 14mm;
    }}
    :root {{
      color-scheme: light;
      --ink: #1d2630;
      --line: #d8dee7;
      --muted: #64748b;
      --paper: #ffffff;
      --panel: #f7f9fc;
      --accent: #0f766e;
    }}
    html, body {{
      margin: 0;
      padding: 0;
      background: #eef2f7;
      color: var(--ink);
      font-family: "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", sans-serif;
      line-height: 1.65;
      font-size: 12pt;
    }}
    body {{
      padding: 0;
    }}
    .page {{
      box-sizing: border-box;
      width: 210mm;
      min-height: 297mm;
      margin: 0 auto;
      padding: 16mm 14mm;
      background: var(--paper);
    }}
    h1, h2, h3, h4, h5, h6 {{
      margin: 0 0 10px;
      line-height: 1.35;
      color: #102a43;
    }}
    h1 {{
      font-size: 22pt;
      margin-top: 0;
      padding-bottom: 10px;
      border-bottom: 2px solid var(--line);
    }}
    h2 {{
      font-size: 16pt;
      margin-top: 24px;
    }}
    h3 {{
      font-size: 13.5pt;
      margin-top: 18px;
    }}
    p, ul, ol, blockquote, pre, table {{
      margin: 0 0 12px;
    }}
    ul, ol {{
      padding-left: 22px;
    }}
    li {{
      margin: 4px 0;
    }}
    blockquote {{
      padding: 10px 14px;
      background: #f6fbfb;
      border-left: 4px solid #94d2bd;
      color: #0f172a;
    }}
    code {{
      font-family: "Cascadia Mono", "Consolas", monospace;
      font-size: 0.92em;
      background: #eef2ff;
      color: #1e3a8a;
      border-radius: 4px;
      padding: 1px 4px;
    }}
    pre {{
      overflow: hidden;
      padding: 12px 14px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #0f172a;
      color: #e2e8f0;
      font-family: "Cascadia Mono", "Consolas", monospace;
      font-size: 9.5pt;
      line-height: 1.45;
      white-space: pre-wrap;
      word-break: break-word;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      table-layout: fixed;
      page-break-inside: avoid;
    }}
    th, td {{
      border: 1px solid var(--line);
      padding: 8px 10px;
      text-align: left;
      vertical-align: top;
      word-break: break-word;
    }}
    th {{
      background: var(--panel);
      font-weight: 700;
    }}
    .doc-meta {{
      margin-bottom: 18px;
      color: var(--muted);
      font-size: 10.5pt;
    }}
    .doc-footer {{
      margin-top: 24px;
      padding-top: 12px;
      border-top: 1px solid var(--line);
      color: var(--muted);
      font-size: 9.5pt;
    }}
    {extra_css}
  </style>
</head>
<body>
  <main class="page">
    {body}
  </main>
</body>
</html>
"""


def render_inline(text: str) -> str:
    parts = text.split("`")
    rendered: list[str] = []
    for index, part in enumerate(parts):
        escaped = html.escape(part)
        if index % 2 == 1:
            rendered.append(f"<code>{escaped}</code>")
        else:
            rendered.append(escaped)
    return "".join(rendered)


def is_table_divider(line: str) -> bool:
    stripped = line.strip()
    if not stripped.startswith("|"):
        return False
    cells = [cell.strip() for cell in stripped.strip("|").split("|")]
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def split_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_special_block_start(lines: list[str], index: int) -> bool:
    stripped = lines[index].strip()
    if not stripped:
        return True
    if stripped.startswith(("```", "#", ">", "|")):
        return True
    if re.match(r"^[-*]\s+", stripped):
        return True
    if re.match(r"^\d+\.\s+", stripped):
        return True
    if index + 1 < len(lines) and lines[index].strip().startswith("|") and is_table_divider(lines[index + 1]):
        return True
    return False


def markdown_to_html(markdown_text: str, title: str) -> str:
    lines = markdown_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    blocks: list[str] = [f"<h1>{html.escape(title)}</h1>", '<div class="doc-meta">导出日期：2026-03-18</div>']
    index = 0

    while index < len(lines):
        line = lines[index]
        stripped = line.strip()

        if not stripped:
            index += 1
            continue

        if stripped.startswith("```"):
            fence = stripped[:3]
            code_lines: list[str] = []
            index += 1
            while index < len(lines) and not lines[index].strip().startswith(fence):
                code_lines.append(lines[index].rstrip("\n"))
                index += 1
            blocks.append(f"<pre>{html.escape(chr(10).join(code_lines))}</pre>")
            index += 1
            continue

        heading = re.match(r"^(#{1,6})\s+(.*)$", stripped)
        if heading:
            level = len(heading.group(1))
            text = render_inline(heading.group(2).strip())
            blocks.append(f"<h{level}>{text}</h{level}>")
            index += 1
            continue

        if stripped.startswith("|") and index + 1 < len(lines) and is_table_divider(lines[index + 1]):
            headers = split_table_row(lines[index])
            rows: list[list[str]] = []
            index += 2
            while index < len(lines):
                candidate = lines[index].strip()
                if not candidate.startswith("|") or is_table_divider(candidate):
                    break
                rows.append(split_table_row(candidate))
                index += 1
            thead = "".join(f"<th>{render_inline(cell)}</th>" for cell in headers)
            tbody_rows = []
            for row in rows:
                columns = row + [""] * max(0, len(headers) - len(row))
                tbody_rows.append("<tr>" + "".join(f"<td>{render_inline(cell)}</td>" for cell in columns[: len(headers)]) + "</tr>")
            blocks.append(f"<table><thead><tr>{thead}</tr></thead><tbody>{''.join(tbody_rows)}</tbody></table>")
            continue

        if stripped.startswith(">"):
            quote_lines: list[str] = []
            while index < len(lines) and lines[index].strip().startswith(">"):
                quote_lines.append(lines[index].strip()[1:].lstrip())
                index += 1
            blocks.append("<blockquote><p>" + "<br>".join(render_inline(item) for item in quote_lines if item) + "</p></blockquote>")
            continue

        if re.match(r"^[-*]\s+", stripped):
            items: list[str] = []
            while index < len(lines) and re.match(r"^[-*]\s+", lines[index].strip()):
                items.append(re.sub(r"^[-*]\s+", "", lines[index].strip(), count=1))
                index += 1
            blocks.append("<ul>" + "".join(f"<li>{render_inline(item)}</li>" for item in items) + "</ul>")
            continue

        if re.match(r"^\d+\.\s+", stripped):
            items = []
            while index < len(lines) and re.match(r"^\d+\.\s+", lines[index].strip()):
                items.append(re.sub(r"^\d+\.\s+", "", lines[index].strip(), count=1))
                index += 1
            blocks.append("<ol>" + "".join(f"<li>{render_inline(item)}</li>" for item in items) + "</ol>")
            continue

        paragraph_lines = [stripped]
        index += 1
        while index < len(lines) and not is_special_block_start(lines, index):
            paragraph_lines.append(lines[index].strip())
            index += 1
        blocks.append(f"<p>{render_inline(' '.join(paragraph_lines))}</p>")

    return html_document(title, "\n".join(blocks))


def build_source_html(lines: list[str]) -> str:
    normalized = [line.rstrip("\n").replace("\t", "    ") for line in lines]
    lines_per_page = 55
    pages = [normalized[offset : offset + lines_per_page] for offset in range(0, len(normalized), lines_per_page)]
    if not pages:
        pages = [[]]
    total_pages = len(pages)
    selected_pages = pages if total_pages <= 60 else pages[:30] + pages[-30:]

    page_html: list[str] = []
    for selected_index, page_lines in enumerate(selected_pages, start=1):
        if total_pages > 60 and selected_index > 30:
            original_page_index = total_pages - 30 + (selected_index - 31)
        else:
            original_page_index = selected_index - 1
        header = (
            f'<div class="code-header">'
            f'<span>仁迈 V1.0.0 源程序鉴别材料</span>'
            f'<span>原始页码 {original_page_index + 1}/{total_pages}</span>'
            f"</div>"
        )
        line_items = "".join(f'<div class="code-line">{html.escape(item)}</div>' for item in page_lines)
        if len(page_lines) < lines_per_page:
            line_items += "".join('<div class="code-line">&nbsp;</div>' for _ in range(lines_per_page - len(page_lines)))
        page_html.append(f'<section class="code-page">{header}<div class="code-body">{line_items}</div></section>')

    body = "".join(page_html)
    extra_css = """
    @page {
      size: A4;
      margin: 10mm 8mm 10mm 10mm;
    }
    html, body {
      background: #f4f6fb;
      font-family: "Cascadia Mono", "Consolas", "Microsoft YaHei", monospace;
      font-size: 9pt;
      line-height: 1.25;
    }
    .page {
      width: auto;
      min-height: auto;
      padding: 0;
      background: transparent;
      box-shadow: none;
    }
    .code-page {
      box-sizing: border-box;
      width: 190mm;
      min-height: 277mm;
      margin: 0 auto;
      padding: 6mm 5mm;
      background: #ffffff;
      page-break-after: always;
      border: 1px solid #d6deeb;
    }
    .code-page:last-of-type {
      page-break-after: auto;
    }
    .code-header {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 6px;
      color: #334155;
      font-size: 8pt;
    }
    .code-body {
      border-top: 1px solid #d6deeb;
      padding-top: 4px;
    }
    .code-line {
      min-height: 4.45mm;
      white-space: pre;
      overflow: hidden;
      text-overflow: clip;
      font-size: 7.2pt;
      line-height: 1.22;
      color: #0f172a;
    }
    """
    return html_document("仁迈 V1.0.0 源程序鉴别材料", body, extra_css=extra_css)


def detect_chrome() -> Path:
    candidates = [
        Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
        Path(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
        Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
        Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    for command in ("chrome", "msedge"):
        resolved = shutil.which(command)
        if resolved:
            return Path(resolved)
    raise FileNotFoundError("Chrome or Edge was not found on this machine.")


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def start_server(root: Path) -> tuple[ThreadingHTTPServer, int]:
    port = find_free_port()
    handler = partial(SilentHandler, directory=str(root))
    server = ThreadingHTTPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    time.sleep(0.2)
    return server, port


def decode_process_output(buffer: bytes) -> str:
    if not buffer:
        return ""
    for encoding in ("utf-8", "utf-8-sig", "gb18030", "gbk", "latin-1"):
        try:
            return buffer.decode(encoding)
        except UnicodeDecodeError:
            continue
    return buffer.decode("utf-8", errors="ignore")


def run_chrome_capture(
    chrome_path: Path,
    url: str,
    output_path: Path,
    *,
    mode: str,
    width: int = 1680,
    height: int = 2200,
    virtual_time_budget: int = 8000,
) -> None:
    ensure_dir(output_path.parent)
    ensure_dir(HEADLESS_WORK_ROOT)
    if output_path.exists():
        output_path.unlink()

    last_error = ""
    pdf_flag_sets = [["--no-pdf-header-footer"], ["--print-to-pdf-no-header"], []] if mode == "pdf" else [[]]

    for headless_flag in ("--headless=new", "--headless"):
        for pdf_flags in pdf_flag_sets:
            temp_profile = HEADLESS_WORK_ROOT / f"profile-{uuid.uuid4().hex}"
            temp_output_dir = HEADLESS_WORK_ROOT / f"render-{uuid.uuid4().hex}"
            ensure_dir(temp_profile)
            ensure_dir(temp_output_dir)
            temp_output_path = temp_output_dir / output_path.name
            args = [
                str(chrome_path),
                headless_flag,
                "--disable-gpu",
                "--hide-scrollbars",
                "--run-all-compositor-stages-before-draw",
                f"--virtual-time-budget={virtual_time_budget}",
                f"--user-data-dir={temp_profile}",
            ]
            if mode == "pdf":
                args.extend(
                    [
                        f"--print-to-pdf={temp_output_path}",
                        *pdf_flags,
                    ]
                )
            else:
                args.extend(
                    [
                        f"--window-size={width},{height}",
                        "--force-device-scale-factor=1",
                        f"--screenshot={temp_output_path}",
                    ]
                )
            args.append(url)

            try:
                result = subprocess.run(args, capture_output=True, text=False, check=False)
                stdout = decode_process_output(result.stdout).strip()
                stderr = decode_process_output(result.stderr).strip()
                if result.returncode == 0 and temp_output_path.exists() and temp_output_path.stat().st_size > 0:
                    shutil.copy2(temp_output_path, output_path)
                    return
                last_error = "\n".join(
                    item
                    for item in [
                        f"Command: {' '.join(args)}",
                        f"Exit code: {result.returncode}",
                        stderr,
                        stdout,
                    ]
                    if item
                )
            finally:
                shutil.rmtree(temp_profile, ignore_errors=True)
                shutil.rmtree(temp_output_dir, ignore_errors=True)

    raise RuntimeError(f"Chrome failed to generate {output_path.name}: {last_error}")


def create_capture_helper(
    path: Path,
    *,
    title: str,
    target: str,
    auth_state: dict | None = None,
    auth_session: dict | None = None,
    app_state: dict | None = None,
) -> None:
    clear_keys = [
        STORAGE_KEY,
        AUTH_STORAGE_KEY,
        AUTH_SESSION_KEY,
        PUBLIC_AUTH_FLOW_STORAGE_KEY,
        LOCAL_REGISTER_FLOW_KEY,
        SECRET_STORAGE_KEY,
        GEO_STORAGE_KEY,
    ]
    payload = {
        "clearKeys": clear_keys,
        "storageKey": STORAGE_KEY,
        "authStorageKey": AUTH_STORAGE_KEY,
        "authSessionKey": AUTH_SESSION_KEY,
        "authState": auth_state,
        "authSession": auth_session,
        "appState": app_state,
        "target": target,
    }
    content = f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <style>
    html, body {{
      margin: 0;
      min-height: 100%;
      display: grid;
      place-items: center;
      background: #0f172a;
      color: #e2e8f0;
      font-family: "Microsoft YaHei", sans-serif;
    }}
    .hint {{
      padding: 18px 22px;
      border: 1px solid rgba(255, 255, 255, 0.18);
      border-radius: 14px;
      background: rgba(15, 23, 42, 0.78);
    }}
  </style>
</head>
<body>
  <div class="hint">Preparing capture...</div>
  <script>
    (function () {{
      const payload = {json.dumps(payload, ensure_ascii=False)};
      try {{
        payload.clearKeys.forEach((key) => {{
          localStorage.removeItem(key);
          sessionStorage.removeItem(key);
        }});
        if (payload.authState) {{
          localStorage.setItem(payload.authStorageKey, JSON.stringify(payload.authState));
        }}
        if (payload.authSession) {{
          const raw = JSON.stringify(payload.authSession);
          localStorage.setItem(payload.authSessionKey, raw);
          sessionStorage.setItem(payload.authSessionKey, raw);
        }}
        if (payload.appState) {{
          localStorage.setItem(payload.storageKey, JSON.stringify(payload.appState));
        }}
      }} catch (error) {{
        console.error(error);
      }}
      window.setTimeout(() => window.location.replace(payload.target), 120);
    }})();
  </script>
</body>
</html>
"""
    write_text(path, content)


def generate_document_pdfs(chrome_path: Path, base_url: str) -> list[Path]:
    generated_files: list[Path] = []

    for spec in DOCUMENT_SPECS:
        markdown = read_text(spec["source"])
        html_path = HTML_ROOT / f"{spec['slug']}.html"
        pdf_path = PDF_ROOT / f"{spec['slug']}.pdf"
        package_target = spec["package_target"]

        write_text(html_path, markdown_to_html(markdown, spec["title"]))
        run_chrome_capture(chrome_path, f"{base_url}/{html_path.relative_to(ROOT).as_posix()}", pdf_path, mode="pdf", virtual_time_budget=2500)
        ensure_dir(package_target.parent)
        shutil.copy2(pdf_path, package_target)
        generated_files.append(package_target)

    source_bundle_path = OUTPUT_ROOT / "renmai-web-source-bundle.txt"
    if not source_bundle_path.exists():
        raise FileNotFoundError(f"Missing source bundle: {source_bundle_path}")

    source_lines = read_text(source_bundle_path).splitlines()
    source_html_path = HTML_ROOT / "source-program-print.html"
    source_pdf_path = PDF_ROOT / "source-program-print.pdf"
    source_package_target = PACKAGE_ROOT / "04_源程序" / "源程序鉴别材料.pdf"

    write_text(source_html_path, build_source_html(source_lines))
    run_chrome_capture(chrome_path, f"{base_url}/{source_html_path.relative_to(ROOT).as_posix()}", source_pdf_path, mode="pdf", virtual_time_budget=2500)
    ensure_dir(source_package_target.parent)
    shutil.copy2(source_pdf_path, source_package_target)
    generated_files.append(source_package_target)

    return generated_files


def generate_screenshots(chrome_path: Path, base_url: str) -> list[Path]:
    generated_files: list[Path] = []
    target_dir = PACKAGE_ROOT / "03_界面截图"
    ensure_dir(target_dir)

    for spec in SCREENSHOT_SPECS:
        helper_path = AUTOMATION_ROOT / f"{spec['slug']}.html"
        generated_path = SCREENSHOT_ROOT / f"{spec['slug']}.png"
        package_target = target_dir / spec["filename"]

        create_capture_helper(
            helper_path,
            title=spec["slug"],
            target=spec["target"],
            auth_state=spec.get("auth_state"),
            auth_session=spec.get("auth_session"),
            app_state=spec.get("app_state"),
        )
        run_chrome_capture(
            chrome_path,
            f"{base_url}/{helper_path.relative_to(ROOT).as_posix()}",
            generated_path,
            mode="screenshot",
            width=spec["window_size"][0],
            height=spec["window_size"][1],
            virtual_time_budget=9000,
        )
        shutil.copy2(generated_path, package_target)
        generated_files.append(package_target)

    return generated_files


def write_summary(generated_paths: list[Path]) -> Path:
    summary_path = GENERATED_ROOT / "generation-summary.txt"
    relative_lines = [str(path.relative_to(ROOT)) for path in generated_paths]
    content = "\n".join(
        [
            "Renmai softcopyright assets generated on 2026-03-18.",
            "",
            "Files copied into submission package:",
            *[f"- {item}" for item in relative_lines],
            "",
            "Official application PDF still needs to be exported from the submission system after real-name verification.",
        ]
    )
    write_text(summary_path, content)
    return summary_path


def main() -> int:
    ensure_dir(GENERATED_ROOT)
    ensure_dir(HTML_ROOT)
    ensure_dir(PDF_ROOT)
    ensure_dir(SCREENSHOT_ROOT)
    ensure_dir(AUTOMATION_ROOT)

    chrome_path = detect_chrome()
    server, port = start_server(ROOT)
    base_url = f"http://127.0.0.1:{port}"

    try:
        generated = []
        generated.extend(generate_document_pdfs(chrome_path, base_url))
        generated.extend(generate_screenshots(chrome_path, base_url))
        summary_path = write_summary(generated)
    finally:
        server.shutdown()
        server.server_close()

    print(f"Generated {len(generated)} softcopyright assets.")
    for item in generated:
        print(item)
    print(summary_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
