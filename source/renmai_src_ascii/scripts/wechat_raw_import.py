import argparse
import base64
import ctypes
import hashlib
import hmac
import json
import os
import re
import shutil
import sqlite3
import struct
import subprocess
import sys
import tempfile
import unicodedata
import wave
import xml.etree.ElementTree as ET
import zipfile
from ctypes import wintypes
from multiprocessing import Pool, cpu_count

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="ignore")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
VENDOR_DIR = os.path.join(SCRIPT_DIR, "vendor")


def _bootstrap_vendor_packages():
    if not os.path.isdir(VENDOR_DIR):
        return
    extract_root = os.path.join(
        tempfile.gettempdir(),
        "renmai_script_vendor",
        "py%s%s" % (sys.version_info[0], sys.version_info[1]),
    )
    os.makedirs(extract_root, exist_ok=True)
    for name in sorted(os.listdir(VENDOR_DIR)):
        path = os.path.join(VENDOR_DIR, name)
        if os.path.isdir(path):
            if path not in sys.path:
                sys.path.insert(0, path)
            continue
        if not name.lower().endswith(".whl"):
            continue
        target = os.path.join(extract_root, os.path.splitext(name)[0])
        if not os.path.isdir(target):
            with zipfile.ZipFile(path) as archive:
                archive.extractall(target)
        if target not in sys.path:
            sys.path.insert(0, target)


_bootstrap_vendor_packages()

try:
    import compression.zstd as _builtin_zstd
except Exception:
    _builtin_zstd = None

try:
    import zstandard as _external_zstd
except Exception:
    _external_zstd = None

try:
    import pysilk
except Exception:
    pysilk = None

try:
    from Cryptodome.Cipher import AES
    from Cryptodome.Hash import SHA512
    from Cryptodome.Protocol.KDF import PBKDF2
except Exception as exc:
    print(
        json.dumps(
            {
                "ok": False,
                "error": "缺少 Python 依赖 Cryptodome，当前机器无法解密微信原始数据库：%s"
                % exc,
            },
            ensure_ascii=False,
        )
    )
    raise SystemExit(0)

PROCESS_VM_READ = 0x0010
PROCESS_QUERY_INFORMATION = 0x0400
MEM_COMMIT = 0x1000
MEM_PRIVATE = 0x20000
PAGE_SIZE = 4096
SALT_SIZE = 16
KEY_SIZE = 32
ROUND_COUNT = 256000
IV_SIZE = 16
HMAC_SHA512_SIZE = 64
AES_BLOCK_SIZE = 16

PATH_RE = re.compile(
    rb"[a-zA-Z]:\\\\(?:.{1,100}?\\\\){0,2}?(?:xwechat_files|WeChat Files)\\\\[0-9a-zA-Z_-]{2,80}?\\\\db_storage\\\\",
    re.I | re.S,
)
KEY_RE = re.compile(rb".{6}\x00{2}\x00{8}\x20\x00{7}\x2f\x00{7}", re.S)
RAW_KEY_RE = re.compile(rb"""x['"]([0-9a-fA-F]{96})['"]""", re.I)
WECHAT_PROCESS_NAMES = ("Weixin.exe", "WeChat.exe")
CACHE_FILE_NAME = "wechat_key_cache.json"


class MEMORY_BASIC_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("BaseAddress", ctypes.c_void_p),
        ("AllocationBase", ctypes.c_void_p),
        ("AllocationProtect", ctypes.c_ulong),
        ("RegionSize", ctypes.c_size_t),
        ("State", ctypes.c_ulong),
        ("Protect", ctypes.c_ulong),
        ("Type", ctypes.c_ulong),
    ]


kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
OpenProcess = kernel32.OpenProcess
OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
OpenProcess.restype = wintypes.HANDLE
ReadProcessMemory = kernel32.ReadProcessMemory
ReadProcessMemory.argtypes = [
    wintypes.HANDLE,
    wintypes.LPCVOID,
    wintypes.LPVOID,
    ctypes.c_size_t,
    ctypes.POINTER(ctypes.c_size_t),
]
ReadProcessMemory.restype = wintypes.BOOL
VirtualQueryEx = kernel32.VirtualQueryEx
VirtualQueryEx.argtypes = [
    wintypes.HANDLE,
    wintypes.LPCVOID,
    ctypes.POINTER(MEMORY_BASIC_INFORMATION),
    ctypes.c_size_t,
]
VirtualQueryEx.restype = ctypes.c_size_t
CloseHandle = kernel32.CloseHandle
CloseHandle.argtypes = [wintypes.HANDLE]
CloseHandle.restype = wintypes.BOOL


def normalize_path(path):
    return os.path.normpath(path)


def iter_weixin_pids():
    pids = []
    seen = set()
    for process_name in WECHAT_PROCESS_NAMES:
        try:
            output = subprocess.check_output(
                ["tasklist", "/FI", "IMAGENAME eq %s" % process_name, "/FO", "CSV", "/NH"],
                text=True,
                encoding="utf-8",
                errors="ignore",
            )
        except Exception:
            continue

        for line in output.splitlines():
            line = line.strip()
            if not line or "No tasks are running" in line:
                continue
            parts = [item.strip('"') for item in line.split('","')]
            if len(parts) < 2:
                continue
            if parts[0].strip('"').lower() != process_name.lower():
                continue
            try:
                pid = int(parts[1].replace(",", "").strip('"'))
            except Exception:
                continue
            if pid not in seen:
                seen.add(pid)
                pids.append(pid)
    return pids


def _cache_root():
    appdata = os.environ.get("APPDATA")
    if appdata:
        return os.path.join(appdata, "Renmai")
    return os.path.join(tempfile.gettempdir(), "Renmai")


def _cache_file_path():
    return os.path.join(_cache_root(), CACHE_FILE_NAME)


def _load_json_file(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return None


def _save_json_file(path, payload):
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)


def _iter_external_key_sources():
    candidates = []
    env_path = os.environ.get("RENMAI_WECHAT_KEY_CACHE")
    if env_path:
        candidates.append(env_path)

    documents = os.path.join(os.path.expanduser("~"), "Documents")
    candidates.append(os.path.join(documents, "tmp_wx_dump_4", "backend", "config", "wx_keys_backup.json"))
    candidates.append(_cache_file_path())

    seen = set()
    for path in candidates:
        normalized = normalize_path(path)
        if normalized in seen or not os.path.exists(normalized):
            continue
        seen.add(normalized)
        yield normalized


def _extract_key_candidates_from_payload(payload, account_root, sample_salt_hex):
    account_id = os.path.basename(account_root)
    candidates = []

    if isinstance(payload, dict):
        scoped = payload.get("accounts")
        if isinstance(scoped, dict):
            payload = [scoped.get(account_id), scoped.get(sample_salt_hex), scoped]

        for key, value in payload.items():
            if isinstance(value, dict):
                key_value = value.get("key") or value.get("passphrase")
                if isinstance(key_value, str):
                    candidates.append(key_value)
                cached_accounts = value.get("accounts")
                if isinstance(cached_accounts, dict):
                    candidates.extend(
                        _extract_key_candidates_from_payload(
                            cached_accounts, account_root, sample_salt_hex
                        )
                    )
            elif isinstance(value, str):
                if re.fullmatch(r"[0-9a-fA-F]{64,96}", value):
                    candidates.append(value)
        return candidates

    if isinstance(payload, list):
        for item in payload:
            candidates.extend(
                _extract_key_candidates_from_payload(item, account_root, sample_salt_hex)
            )
        return candidates

    if isinstance(payload, str) and re.fullmatch(r"[0-9a-fA-F]{64,96}", payload):
        candidates.append(payload)
    return candidates


def load_cached_key_candidates(account_root, sample_salt_hex):
    seen = set()
    keys = []
    for path in _iter_external_key_sources():
        payload = _load_json_file(path)
        if payload is None:
            continue
        for candidate in _extract_key_candidates_from_payload(
            payload, account_root, sample_salt_hex
        ):
            normalized = candidate.strip().lower()
            if normalized in seen:
                continue
            seen.add(normalized)
            keys.append(normalized)
    return keys


def persist_cached_key(account_root, sample_salt_hex, key_material):
    key_hex = key_material.get("passphrase")
    if not key_hex:
        return

    path = _cache_file_path()
    payload = _load_json_file(path)
    if not isinstance(payload, dict):
        payload = {}
    accounts = payload.get("accounts")
    if not isinstance(accounts, dict):
        accounts = {}
        payload["accounts"] = accounts

    account_id = os.path.basename(account_root)
    accounts[account_id] = {
        "key": key_hex,
        "sample_salt": sample_salt_hex,
        "updated_at": __import__("datetime").datetime.utcnow().isoformat() + "Z",
    }
    _save_json_file(path, payload)


def open_process(pid):
    return OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, False, pid)


def read_process_memory(handle, address, size):
    buffer = ctypes.create_string_buffer(size)
    bytes_read = ctypes.c_size_t(0)
    success = ReadProcessMemory(
        handle,
        ctypes.c_void_p(address),
        buffer,
        size,
        ctypes.byref(bytes_read),
    )
    if not success or bytes_read.value == 0:
        return b""
    return buffer.raw[: bytes_read.value]


def get_memory_regions(handle):
    mbi = MEMORY_BASIC_INFORMATION()
    address = 0
    last_base = -1
    while address < (1 << 47):
        result = VirtualQueryEx(
            handle,
            ctypes.c_void_p(address),
            ctypes.byref(mbi),
            ctypes.sizeof(mbi),
        )
        if not result:
            break
        base = int(mbi.BaseAddress or 0)
        size = int(mbi.RegionSize or 0)
        if size <= 0 or base == last_base:
            address += 0x1000
            continue
        last_base = base
        if mbi.State == MEM_COMMIT and mbi.Type == MEM_PRIVATE:
            yield base, size
        address = base + size


def iter_region_chunks(handle, min_contains=None, chunk_size=2 * 1024 * 1024, overlap=128):
    for base, size in get_memory_regions(handle):
        offset = 0
        while offset < size:
            want = min(chunk_size, size - offset)
            if want <= 0:
                break
            data = read_process_memory(handle, base + offset, want)
            if data and (min_contains is None or min_contains in data):
                yield base + offset, data
            offset += want - overlap if want > overlap else want


def find_data_dirs(handle):
    hits = []
    for _, data in iter_region_chunks(handle, min_contains=b"db_storage"):
        for match in PATH_RE.finditer(data):
            value = match.group(0).rstrip(b"\x00").decode("utf-8", errors="ignore")
            if value:
                hits.append(normalize_path(value.rstrip("\\/")))
    return hits


def pick_matching_pids(account_root):
    db_storage = normalize_path(os.path.join(account_root, "db_storage")).lower()
    matched = []
    fallback = []
    for pid in iter_weixin_pids():
        handle = open_process(pid)
        if not handle:
            continue
        try:
            dirs = find_data_dirs(handle)
        finally:
            CloseHandle(handle)
        if any(db_storage in item.lower() for item in dirs):
            matched.append(pid)
        fallback.append(pid)
    return matched or fallback


def is_binary_like_key(value):
    if len(value) != 32:
        return False
    if value == b"\x00" * 32 or value == b"\xaa" * 32:
        return False
    printable = sum(32 <= item < 127 for item in value)
    return printable < 32


def collect_candidate_keys(pid):
    handle = open_process(pid)
    if not handle:
        return []
    seen_addrs = set()
    seen_keys = set()
    candidates = []
    try:
        for _, data in iter_region_chunks(handle):
            for match in KEY_RE.finditer(data):
                address = struct.unpack_from("<Q", match.group(0), 0)[0]
                if address in seen_addrs:
                    continue
                seen_addrs.add(address)
                key = read_process_memory(handle, address, 32)
                if not is_binary_like_key(key):
                    continue
                if key in seen_keys:
                    continue
                seen_keys.add(key)
                candidates.append(key)
    finally:
        CloseHandle(handle)
    return candidates


def collect_raw_key_map(pid):
    handle = open_process(pid)
    if not handle:
        return {}
    candidates = {}
    try:
        for _, data in iter_region_chunks(handle, min_contains=b"x'"):
            for match in RAW_KEY_RE.finditer(data):
                raw_hex = match.group(1).decode("ascii", errors="ignore").lower()
                if len(raw_hex) < 96:
                    continue
                candidates[raw_hex[64:96]] = raw_hex
    finally:
        CloseHandle(handle)
    return candidates


def verify_key_candidate(args):
    candidate, buffer_ = args
    try:
        salt = buffer_[:SALT_SIZE]
        mac_salt = bytes(item ^ 0x3A for item in salt)
        derived_key = PBKDF2(
            candidate,
            salt,
            dkLen=KEY_SIZE,
            count=ROUND_COUNT,
            hmac_hash_module=SHA512,
        )
        mac_key = PBKDF2(
            derived_key,
            mac_salt,
            dkLen=KEY_SIZE,
            count=2,
            hmac_hash_module=SHA512,
        )
        reserve = IV_SIZE + HMAC_SHA512_SIZE
        reserve = ((reserve + AES_BLOCK_SIZE - 1) // AES_BLOCK_SIZE) * AES_BLOCK_SIZE
        mac = hmac.new(
            mac_key,
            buffer_[SALT_SIZE : PAGE_SIZE - reserve + IV_SIZE],
            hashlib.sha512,
        )
        mac.update(struct.pack("<I", 1))
        expected = mac.digest()
        start = PAGE_SIZE - reserve + IV_SIZE
        if expected == buffer_[start : start + len(expected)]:
            return candidate.hex()
    except Exception:
        return None
    return None


def verify_raw_key_candidate(raw_key_hex, buffer_):
    try:
        if len(raw_key_hex) < 96:
            return False
        derived_key = bytes.fromhex(raw_key_hex[:64])
        salt = bytes.fromhex(raw_key_hex[64:96])
        if buffer_[:SALT_SIZE] != salt:
            return False
        mac_salt = bytes(item ^ 0x3A for item in salt)
        mac_key = PBKDF2(
            derived_key,
            mac_salt,
            dkLen=KEY_SIZE,
            count=2,
            hmac_hash_module=SHA512,
        )
        reserve = IV_SIZE + HMAC_SHA512_SIZE
        reserve = ((reserve + AES_BLOCK_SIZE - 1) // AES_BLOCK_SIZE) * AES_BLOCK_SIZE
        mac = hmac.new(
            mac_key,
            buffer_[SALT_SIZE : PAGE_SIZE - reserve + IV_SIZE],
            hashlib.sha512,
        )
        mac.update(struct.pack("<I", 1))
        expected = mac.digest()
        start = PAGE_SIZE - reserve + IV_SIZE
        return expected == buffer_[start : start + len(expected)]
    except Exception:
        return False


def read_sample_db(account_root):
    for relative in (
        os.path.join("db_storage", "favorite", "favorite_fts.db"),
        os.path.join("db_storage", "head_image", "head_image.db"),
    ):
        path = os.path.join(account_root, relative)
        if os.path.exists(path):
            with open(path, "rb") as handle:
                return path, handle.read(PAGE_SIZE)
    raise FileNotFoundError("未找到可用于校验 key 的微信数据库样本。")


def find_db_key(account_root):
    sample_path, sample_buffer = read_sample_db(account_root)
    sample_salt_hex = sample_buffer[:SALT_SIZE].hex().lower()
    diagnostics = {
        "sample_db": sample_path,
        "sample_salt": sample_salt_hex,
        "process_count": 0,
        "candidate_pids": [],
        "candidate_key_count": 0,
        "raw_key_candidate_count": 0,
        "cache_key_candidate_count": 0,
        "cache_hit": False,
    }

    cached_keys = load_cached_key_candidates(account_root, sample_salt_hex)
    diagnostics["cache_key_candidate_count"] = len(cached_keys)
    for cached_key in cached_keys:
        if len(cached_key) >= 96 and verify_raw_key_candidate(cached_key, sample_buffer):
            diagnostics["cache_hit"] = True
            return {"passphrase": cached_key}, diagnostics
        if verify_key_candidate((bytes.fromhex(cached_key[:64]), sample_buffer)):
            diagnostics["cache_hit"] = True
            return {"passphrase": cached_key[:64]}, diagnostics

    raw_key_map = {}
    matched_pids = pick_matching_pids(account_root)
    diagnostics["process_count"] = len(iter_weixin_pids())

    for pid in matched_pids:
        diagnostics["candidate_pids"].append(pid)
        raw_candidates = collect_raw_key_map(pid)
        diagnostics["raw_key_candidate_count"] += len(raw_candidates)
        raw_key_map.update(raw_candidates)
        raw_key_hex = raw_candidates.get(sample_salt_hex)
        if raw_key_hex and verify_raw_key_candidate(raw_key_hex, sample_buffer):
            diagnostics["cache_hit"] = False
            return {"raw_map": raw_key_map}, diagnostics

        candidates = collect_candidate_keys(pid)
        diagnostics["candidate_key_count"] += len(candidates)
        if not candidates:
            continue
        workers = max(1, cpu_count() // 2)
        with Pool(processes=workers) as pool:
            for result in pool.imap_unordered(
                verify_key_candidate,
                ((candidate, sample_buffer) for candidate in candidates),
                chunksize=8,
            ):
                if result:
                    pool.terminate()
                    pool.join()
                    key_material = {"passphrase": result}
                    persist_cached_key(account_root, sample_salt_hex, key_material)
                    return key_material, diagnostics
    return None, diagnostics


def decrypt_db_file_v4(passphrase_hex, source_path, output_path):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(source_path, "rb") as source, open(output_path, "wb") as target:
        salt = source.read(SALT_SIZE)
        if not salt:
            raise ValueError("数据库为空或已损坏。")
        mac_salt = bytes(item ^ 0x3A for item in salt)
        if len(passphrase_hex) >= 96:
            derived_key = bytes.fromhex(passphrase_hex[:64])
        else:
            passphrase = bytes.fromhex(passphrase_hex)
            derived_key = PBKDF2(
                passphrase,
                salt,
                dkLen=KEY_SIZE,
                count=ROUND_COUNT,
                hmac_hash_module=SHA512,
            )
        mac_key = PBKDF2(
            derived_key,
            mac_salt,
            dkLen=KEY_SIZE,
            count=2,
            hmac_hash_module=SHA512,
        )
        target.write(b"SQLite format 3\x00")
        reserve = IV_SIZE + HMAC_SHA512_SIZE
        reserve = ((reserve + AES_BLOCK_SIZE - 1) // AES_BLOCK_SIZE) * AES_BLOCK_SIZE
        page_index = 0
        while True:
            if page_index == 0:
                page = source.read(PAGE_SIZE - SALT_SIZE)
                if not page:
                    break
                page = salt + page
            else:
                page = source.read(PAGE_SIZE)
            if not page:
                break
            offset = SALT_SIZE if page_index == 0 else 0
            end = len(page)
            mac = hmac.new(
                mac_key,
                page[offset : end - reserve + IV_SIZE],
                hashlib.sha512,
            )
            mac.update(struct.pack("<I", page_index + 1))
            expected = mac.digest()
            start = end - reserve + IV_SIZE
            if expected != page[start : start + len(expected)]:
                raise ValueError("数据库校验失败，key 可能不正确。")
            iv = page[end - reserve : end - reserve + IV_SIZE]
            cipher = AES.new(derived_key, AES.MODE_CBC, iv)
            decrypted = cipher.decrypt(page[offset : end - reserve])
            target.write(decrypted)
            target.write(page[end - reserve : end])
            page_index += 1


def decrypt_required_dbs(account_root, key_material, temp_root, include_media=False):
    decrypted_root = os.path.join(temp_root, os.path.basename(account_root), "db_storage")
    discovered_files = []
    source_db_map = {}

    required = [
        os.path.join("db_storage", "contact", "contact.db"),
        os.path.join("db_storage", "session", "session.db"),
    ]

    message_dir = os.path.join(account_root, "db_storage", "message")
    if os.path.isdir(message_dir):
        for name in sorted(os.listdir(message_dir)):
            if re.match(r"(message|media)_\d+\.db$", name):
                if name.startswith("message_") or include_media:
                    required.append(os.path.join("db_storage", "message", name))
            elif include_media and name == "message_resource.db":
                required.append(os.path.join("db_storage", "message", name))

    for relative in required:
        source_path = os.path.join(account_root, relative)
        if not os.path.exists(source_path):
            continue
        output_path = os.path.join(temp_root, os.path.basename(account_root), relative)
        key_hex = None
        if isinstance(key_material, dict) and key_material.get("raw_map"):
            with open(source_path, "rb") as handle:
                salt_hex = handle.read(SALT_SIZE).hex().lower()
            key_hex = key_material["raw_map"].get(salt_hex)
        elif isinstance(key_material, dict):
            key_hex = key_material.get("passphrase")
        else:
            key_hex = key_material
        if not key_hex:
            raise ValueError("缺少 %s 对应的解密 key。" % os.path.basename(source_path))
        decrypt_db_file_v4(key_hex, source_path, output_path)
        discovered_files.append(source_path)
        source_db_map[output_path] = source_path

    return decrypted_root, discovered_files, source_db_map


def table_exists(connection, table_name):
    cursor = connection.cursor()
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table_name,),
    )
    result = cursor.fetchone()
    cursor.close()
    return bool(result)


def get_columns(connection, table_name):
    cursor = connection.cursor()
    cursor.execute("PRAGMA table_info(%s)" % table_name)
    columns = [row[1] for row in cursor.fetchall()]
    cursor.close()
    return columns


def read_contact_map(contact_db_path):
    contacts = {}
    usernames = set()
    if not os.path.exists(contact_db_path):
        return contacts, usernames

    connection = sqlite3.connect(contact_db_path)
    try:
        if not table_exists(connection, "contact"):
            return contacts, usernames
        columns = set(get_columns(connection, "contact"))
        username_col = "username" if "username" in columns else None
        if not username_col:
            return contacts, usernames
        remark_col = "remark" if "remark" in columns else None
        nick_col = "nick_name" if "nick_name" in columns else None
        alias_col = "alias" if "alias" in columns else None

        select_parts = [username_col]
        for optional in (remark_col, nick_col, alias_col):
            if optional:
                select_parts.append(optional)
            else:
                select_parts.append("NULL")

        cursor = connection.cursor()
        cursor.execute("SELECT %s FROM contact" % ", ".join(select_parts))
        for row in cursor.fetchall():
            username = (row[0] or "").strip()
            if not username:
                continue
            display_name = ""
            for value in row[1:]:
                if value and str(value).strip():
                    display_name = str(value).strip()
                    break
            if not display_name:
                display_name = username
            contacts[username] = display_name
            usernames.add(username)
        cursor.close()
    finally:
        connection.close()

    return contacts, usernames


def read_session_usernames(session_db_path):
    usernames = set()
    if not os.path.exists(session_db_path):
        return usernames

    connection = sqlite3.connect(session_db_path)
    try:
        if not table_exists(connection, "SessionTable"):
            return usernames
        cursor = connection.cursor()
        cursor.execute("SELECT username FROM SessionTable")
        for row in cursor.fetchall():
            username = (row[0] or "").strip()
            if username:
                usernames.add(username)
        cursor.close()
    except Exception:
        return usernames
    finally:
        connection.close()
    return usernames


def sanitize_account_username(account_root):
    base = os.path.basename(account_root)
    candidates = [base]
    if "_" in base:
        prefix = base.rsplit("_", 1)[0]
        if prefix:
            candidates.append(prefix)
    return {item for item in candidates if item}


def _decode_maybe_text(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        decoded = value.decode("utf-8", errors="ignore")
    else:
        decoded = str(value)
    return decoded.strip().strip("\x00")


def _decompress_zstd(payload):
    if not payload:
        return None
    if _builtin_zstd is not None:
        try:
            return _builtin_zstd.decompress(payload)
        except Exception:
            pass
    if _external_zstd is not None:
        try:
            return _external_zstd.ZstdDecompressor().decompress(payload)
        except Exception:
            pass
    return None


def _extract_hex_tokens(value):
    if value is None:
        return []
    if isinstance(value, bytes):
        raw = value
    else:
        raw = str(value).encode("utf-8", errors="ignore")
    tokens = []
    seen = set()
    for match in re.finditer(rb"[0-9a-fA-F]{32}", raw):
        token = match.group(0).decode("ascii", errors="ignore").lower()
        if token in seen:
            continue
        seen.add(token)
        tokens.append(token)
    return tokens


def guess_message_type(local_type):
    mapping = {
        1: "text",
        3: "image",
        34: "voice",
        43: "video",
        47: "emoji",
        49: "file",
        10000: "system",
    }
    return mapping.get(local_type, "other")


def looks_like_xml(text):
    lowered = text.lower()
    return (
        lowered.startswith("<")
        and lowered.endswith(">")
        or "<msg" in lowered
        or "<appmsg" in lowered
    )


def simplify_xml_text(text):
    snippets = []
    for pattern in (
        r"<title><!\[CDATA\[(.*?)\]\]></title>",
        r"<title>(.*?)</title>",
        r"<des><!\[CDATA\[(.*?)\]\]></des>",
        r"<des>(.*?)</des>",
        r"<displayname><!\[CDATA\[(.*?)\]\]></displayname>",
        r"<displayname>(.*?)</displayname>",
    ):
        matches = re.findall(pattern, text, re.I | re.S)
        for value in matches:
            cleaned = re.sub(r"\s+", " ", value).strip()
            if cleaned:
                snippets.append(cleaned)
    if snippets:
        return " / ".join(dict.fromkeys(snippets))
    return ""


def is_readable_plain_text(text):
    if not text:
        return False
    control_count = 0
    useful_count = 0
    preferred_count = 0
    for char in text:
        if char in "\r\n\t":
            useful_count += 1
            continue
        category = unicodedata.category(char)
        if category.startswith("C"):
            control_count += 1
            continue
        useful_count += 1
        if (
            char.isascii()
            and (char.isalnum() or char in " .,:;!?-_/@#%&*()[]{}'\"+=$")
        ) or ("\u4e00" <= char <= "\u9fff"):
            preferred_count += 1

    compact = re.sub(r"\s+", "", text)
    if control_count >= 4 and control_count > max(2, useful_count // 12):
        return False
    if compact and preferred_count / max(1, len(compact)) < 0.35:
        return False
    return True


def _decode_emoji_desc(value):
    if not value:
        return ""

    candidates = []
    seen = set()
    ignored = {
        "default",
        "emoji",
        "sticker",
        "com",
        "tencent",
        "media",
    }

    def add_candidate(text):
        cleaned = re.sub(r"\s+", " ", text).strip().strip("\x00")
        if not cleaned:
            return
        lowered = cleaned.lower()
        if lowered in ignored or cleaned in seen:
            return
        if re.fullmatch(r"[a-z]{2}_[a-z]{2}", lowered):
            return
        if re.search(r"[\uac00-\ud7af]", cleaned):
            return
        if not re.search(r"[\u4e00-\u9fffA-Za-z0-9]", cleaned):
            return
        seen.add(cleaned)
        candidates.append(cleaned)

    if is_readable_plain_text(value) and not re.fullmatch(r"[A-Za-z0-9+/=]+", value):
        add_candidate(value)

    try:
        decoded = base64.b64decode(value + "==", validate=False)
        text = decoded.decode("utf-8", errors="ignore")
        for match in re.finditer(r"[\u4e00-\u9fff]{1,24}|[A-Za-z][A-Za-z0-9 _-]{1,24}", text):
            add_candidate(match.group(0))
    except Exception:
        pass

    return " / ".join(candidates)


def _parse_emoji_payload(message_content, compress_content):
    xml_candidates = []
    for value in (compress_content, message_content):
        if value is None:
            continue
        if isinstance(value, bytes):
            raw = value
            if raw.startswith(b"\x28\xb5\x2f\xfd"):
                decompressed = _decompress_zstd(raw)
                if decompressed:
                    xml_candidates.append(
                        decompressed.decode("utf-8", errors="ignore").strip()
                    )
            xml_candidates.append(raw.decode("utf-8", errors="ignore").strip())
        else:
            text = str(value).strip()
            if text:
                xml_candidates.append(text)

    xml_text = ""
    for candidate in xml_candidates:
        if candidate and looks_like_xml(candidate):
            xml_text = candidate
            break
    if not xml_text:
        return None

    simplified = simplify_xml_text(xml_text)
    desc = ""
    product_id = ""
    try:
        root = ET.fromstring(xml_text)
        emoji_node = root.find("emoji") if root.tag != "emoji" else root
        if emoji_node is not None:
            desc = _decode_emoji_desc(emoji_node.attrib.get("desc", ""))
            product_id = (emoji_node.attrib.get("productid") or "").strip()
    except Exception:
        pass

    lines = ["[表情包]" if (desc or product_id) else "[表情]"]
    if desc:
        lines.append(desc)
    elif simplified:
        lines.append(simplified)

    return {
        "content": "\n".join(item for item in lines if item).strip(),
    }


def _load_message_resource_index(resource_db_path):
    resource_index = {}
    if not os.path.exists(resource_db_path):
        return resource_index

    connection = sqlite3.connect(resource_db_path)
    try:
        chat_name_by_id = {}
        if table_exists(connection, "ChatName2Id"):
            cursor = connection.cursor()
            cursor.execute("SELECT rowid, user_name FROM ChatName2Id")
            for rowid, user_name in cursor.fetchall():
                username = (user_name or "").strip()
                if username:
                    chat_name_by_id[int(rowid)] = username
            cursor.close()

        if not table_exists(connection, "MessageResourceInfo"):
            return resource_index

        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT chat_id, message_local_id, message_svr_id, packed_info
            FROM MessageResourceInfo
            WHERE message_local_type = 3
            """
        )
        for chat_id, local_id, svr_id, packed_info in cursor:
            username = chat_name_by_id.get(int(chat_id or 0))
            tokens = _extract_hex_tokens(packed_info)
            if not username or not tokens:
                continue
            resource_index[(username, int(local_id or 0), int(svr_id or 0))] = tokens
            resource_index[(username, int(local_id or 0), 0)] = tokens
        cursor.close()
    finally:
        connection.close()

    return resource_index


def _load_voice_resource_index(media_db_path):
    voice_index = {}
    if not os.path.exists(media_db_path):
        return voice_index

    connection = sqlite3.connect(media_db_path)
    try:
        name_by_id = {}
        if table_exists(connection, "Name2Id"):
            cursor = connection.cursor()
            cursor.execute("SELECT rowid, user_name FROM Name2Id")
            for rowid, user_name in cursor.fetchall():
                username = (user_name or "").strip()
                if username:
                    name_by_id[int(rowid)] = username
            cursor.close()

        if not table_exists(connection, "VoiceInfo"):
            return voice_index

        cursor = connection.cursor()
        cursor.execute(
            """
            SELECT chat_name_id, local_id, svr_id, voice_data
            FROM VoiceInfo
            WHERE voice_data IS NOT NULL
            """
        )
        for chat_name_id, local_id, svr_id, voice_data in cursor:
            username = name_by_id.get(int(chat_name_id or 0))
            if not username or not voice_data:
                continue
            voice_index[(username, int(local_id or 0), int(svr_id or 0))] = voice_data
            voice_index[(username, int(local_id or 0), 0)] = voice_data
        cursor.close()
    finally:
        connection.close()

    return voice_index


def _build_media_indices(decrypted_root):
    message_dir = os.path.join(decrypted_root, "message")
    message_resource_index = _load_message_resource_index(
        os.path.join(message_dir, "message_resource.db")
    )
    voice_index = {}
    if os.path.isdir(message_dir):
        for name in sorted(os.listdir(message_dir)):
            if not re.match(r"media_\d+\.db$", name):
                continue
            voice_index.update(
                _load_voice_resource_index(os.path.join(message_dir, name))
            )
    return message_resource_index, voice_index


def _safe_media_name(value):
    return re.sub(r"[^0-9A-Za-z._-]+", "_", value).strip("_") or "media"


def _build_attach_image_index(account_root, username):
    index = {}
    session_hash = hashlib.md5(username.encode("utf-8")).hexdigest()
    attach_root = os.path.join(account_root, "msg", "attach", session_hash)
    if not os.path.isdir(attach_root):
        return index

    for root, _dirs, files in os.walk(attach_root):
        if os.path.basename(root).lower() != "img":
            continue
        for name in files:
            lowered = name.lower()
            if not lowered.endswith(".dat"):
                continue
            token = lowered[:-4]
            is_thumb = False
            if token.endswith("_t"):
                token = token[:-2]
                is_thumb = True
            entry = index.setdefault(token, {})
            entry.setdefault("thumb" if is_thumb else "full", os.path.join(root, name))
    return index


def _match_xor_image_header(raw):
    signatures = [
        ("jpg", [(0, b"\xff\xd8\xff")]),
        ("png", [(0, b"\x89PNG\r\n\x1a\n")]),
        ("gif", [(0, b"GIF87a")]),
        ("gif", [(0, b"GIF89a")]),
        ("bmp", [(0, b"BM")]),
        ("webp", [(0, b"RIFF"), (8, b"WEBP")]),
    ]
    for extension, segments in signatures:
        offset, chunk = segments[0]
        if len(raw) <= offset:
            continue
        key = raw[offset] ^ chunk[0]
        matched = True
        for seg_offset, seg_chunk in segments:
            for index, expected in enumerate(seg_chunk):
                position = seg_offset + index
                if position >= len(raw) or (raw[position] ^ key) != expected:
                    matched = False
                    break
            if not matched:
                break
        if matched:
            return extension, key
    return None, None


def _decode_wechat_dat_image(source_path, output_base_path):
    with open(source_path, "rb") as handle:
        raw = handle.read()
    if not raw:
        return ""

    extension, key = _match_xor_image_header(raw)
    if extension is None or key is None:
        return ""

    output_path = "%s.%s" % (output_base_path, extension)
    decoded = bytes(item ^ key for item in raw)
    with open(output_path, "wb") as handle:
        handle.write(decoded)
    return output_path


def _export_image_attachment(
    account_root,
    username,
    stable_id,
    candidate_tokens,
    packed_info_data,
    media_output_dir,
    attach_index_cache,
):
    if not media_output_dir:
        return ""

    tokens = []
    seen = set()
    for token in list(candidate_tokens or []) + _extract_hex_tokens(packed_info_data):
        lowered = token.lower()
        if lowered in seen:
            continue
        seen.add(lowered)
        tokens.append(lowered)
    if not tokens:
        return ""

    if username not in attach_index_cache:
        attach_index_cache[username] = _build_attach_image_index(account_root, username)
    image_index = attach_index_cache.get(username) or {}

    source_path = ""
    for token in tokens:
        entry = image_index.get(token)
        if not entry:
            continue
        source_path = entry.get("full") or entry.get("thumb") or ""
        if source_path:
            break
    if not source_path:
        return ""

    image_dir = os.path.join(media_output_dir, "images")
    os.makedirs(image_dir, exist_ok=True)
    return _decode_wechat_dat_image(
        source_path,
        os.path.join(image_dir, _safe_media_name(stable_id)),
    )


def _export_voice_attachment(stable_id, voice_data, media_output_dir):
    result = {
        "attachment_path": "",
        "decoder_missing": False,
        "decode_failed": False,
    }
    if not media_output_dir or not voice_data:
        return result

    voice_dir = os.path.join(media_output_dir, "voices")
    os.makedirs(voice_dir, exist_ok=True)

    safe_name = _safe_media_name(stable_id)
    silk_path = os.path.join(voice_dir, "%s.silk" % safe_name)
    wav_path = os.path.join(voice_dir, "%s.wav" % safe_name)
    pcm_path = os.path.join(voice_dir, "%s.pcm" % safe_name)

    silk_payload = (
        voice_data[1:]
        if isinstance(voice_data, bytes) and voice_data.startswith(b"\x02#!SILK_V3")
        else voice_data
    )
    with open(silk_path, "wb") as handle:
        handle.write(silk_payload)

    if pysilk is None:
        result["decoder_missing"] = True
        return result

    try:
        with open(silk_path, "rb") as source, open(pcm_path, "wb") as target:
            pysilk.decode(source, target, 24000)
        with open(pcm_path, "rb") as pcm_handle:
            pcm_bytes = pcm_handle.read()
        with wave.open(wav_path, "wb") as wav_handle:
            wav_handle.setnchannels(1)
            wav_handle.setsampwidth(2)
            wav_handle.setframerate(24000)
            wav_handle.writeframes(pcm_bytes)
        result["attachment_path"] = wav_path
        return result
    except Exception:
        result["decode_failed"] = True
        return result
    finally:
        if os.path.exists(pcm_path):
            try:
                os.remove(pcm_path)
            except Exception:
                pass


def _build_media_metadata(
    account_root,
    username,
    local_type,
    local_id,
    server_id,
    message_content,
    compress_content,
    packed_info_data,
    message_resource_index,
    voice_index,
    media_output_dir,
    stable_id,
    attach_index_cache,
):
    metadata = {
        "attachment_path": "",
        "content_override": "",
        "warnings": [],
    }
    lookup_key = (username, int(local_id or 0), int(server_id or 0))
    fallback_key = (username, int(local_id or 0), 0)

    if local_type == 47:
        emoji_payload = _parse_emoji_payload(message_content, compress_content)
        if emoji_payload and emoji_payload.get("content"):
            metadata["content_override"] = emoji_payload["content"]
        return metadata

    if local_type == 3:
        tokens = message_resource_index.get(lookup_key) or message_resource_index.get(
            fallback_key
        )
        metadata["attachment_path"] = _export_image_attachment(
            account_root,
            username,
            stable_id,
            tokens or [],
            packed_info_data,
            media_output_dir,
            attach_index_cache,
        )
        return metadata

    if local_type == 34:
        voice_data = voice_index.get(lookup_key) or voice_index.get(fallback_key)
        export_result = _export_voice_attachment(stable_id, voice_data, media_output_dir)
        metadata["attachment_path"] = export_result.get("attachment_path", "")
        if export_result.get("decoder_missing"):
            metadata["warnings"].append(
                "检测到语音消息，但当前运行环境缺少语音解码组件，暂时无法自动转写。"
            )
        elif export_result.get("decode_failed"):
            metadata["warnings"].append(
                "检测到语音消息，但其中部分语音暂时无法解码，已按语音占位导入。"
            )
        return metadata

    return metadata


def normalize_content(local_type, message_content, compress_content):
    candidates = []
    for value in (message_content, compress_content):
        if value is None:
            continue
        if isinstance(value, bytes):
            decoded = value.decode("utf-8", errors="ignore").strip()
        else:
            decoded = str(value).strip()
        if decoded:
            candidates.append(decoded)

    text = candidates[0] if candidates else ""
    if looks_like_xml(text):
        simplified = simplify_xml_text(text)
        if simplified:
            text = simplified

    prefix_map = {
        3: "[图片]",
        34: "[语音]",
        43: "[视频]",
        47: "[表情]",
        49: "[文件/卡片]",
        10000: "[系统消息]",
    }
    prefix = prefix_map.get(local_type, "")
    if local_type == 1:
        return text if is_readable_plain_text(text) else "[不可直读消息]"
    if local_type not in prefix_map:
        prefix = "[消息类型 %s]" % local_type
    if text and is_readable_plain_text(text):
        return "%s\n%s" % (prefix, text) if prefix else text
    if prefix:
        return prefix
    return text or "[空消息]"


def normalize_contact_id(username):
    safe = re.sub(r"[^\w\u4e00-\u9fa5]+", "_", username).strip("_")
    return safe or username


def clip_snippet(text):
    normalized = re.sub(r"\s+", " ", text).strip()
    if len(normalized) <= 96:
        return normalized
    return normalized[:96] + "..."


def read_messages_for_username(connection, username, sender_column):
    table_name = "Msg_%s" % hashlib.md5(username.encode("utf-8")).hexdigest()
    if not table_exists(connection, table_name):
        return []

    sender_expr = "'' AS sender_username"
    if sender_column:
        sender_expr = "Name2Id.%s AS sender_username" % sender_column

    sql = """
        SELECT
            msg.local_id,
            msg.server_id,
            msg.local_type,
            msg.sort_seq,
            %s,
            msg.create_time,
            msg.status,
            msg.source,
            msg.message_content,
            msg.compress_content
        FROM %s AS msg
        LEFT JOIN Name2Id ON msg.real_sender_id = Name2Id.rowid
        ORDER BY msg.sort_seq
    """ % (
        sender_expr,
        table_name,
    )

    cursor = connection.cursor()
    cursor.execute(sql)
    rows = cursor.fetchall()
    cursor.close()
    return rows


def parse_messages(account_root, package_id, decrypted_root, source_db_map):
    contact_db_path = os.path.join(decrypted_root, "contact", "contact.db")
    session_db_path = os.path.join(decrypted_root, "session", "session.db")
    message_dir = os.path.join(decrypted_root, "message")

    contact_map, usernames = read_contact_map(contact_db_path)
    usernames.update(read_session_usernames(session_db_path))
    if not usernames:
        usernames.update(contact_map.keys())

    self_candidates = sanitize_account_username(account_root)
    records = []

    if not os.path.isdir(message_dir):
        return records

    for name in sorted(os.listdir(message_dir)):
        if not re.match(r"message_\d+\.db$", name):
            continue
        db_path = os.path.join(message_dir, name)
        connection = sqlite3.connect(db_path)
        try:
            name2id_columns = (
                set(get_columns(connection, "Name2Id"))
                if table_exists(connection, "Name2Id")
                else set()
            )
            sender_column = None
            for candidate in ("user_name", "username"):
                if candidate in name2id_columns:
                    sender_column = candidate
                    break

            for username in sorted(usernames):
                for row in read_messages_for_username(connection, username, sender_column):
                    (
                        local_id,
                        server_id,
                        local_type,
                        sort_seq,
                        sender_username,
                        create_time,
                        _status,
                        _source_value,
                        message_content,
                        compress_content,
                    ) = row
                    sender_username = (sender_username or "").strip()
                    is_self = sender_username in self_candidates
                    sender_name = "我" if is_self else contact_map.get(
                        sender_username,
                        sender_username or contact_map.get(username, username),
                    )
                    contact_name = contact_map.get(username, username)
                    content = normalize_content(
                        int(local_type or 0),
                        message_content,
                        compress_content,
                    )
                    for candidate_prefix in (
                        "%s:\n" % sender_username,
                        "%s:" % sender_username,
                        "%s:\n" % username,
                        "%s:" % username,
                    ):
                        if candidate_prefix.strip() and content.startswith(candidate_prefix):
                            content = content[len(candidate_prefix) :].lstrip()
                            break
                    sent_at = int(create_time or 0)
                    if sent_at <= 0:
                        continue
                    message_type = guess_message_type(int(local_type or 0))
                    stable_id = "%s_%s_%s_%s_%s" % (
                        os.path.basename(account_root),
                        username,
                        local_id or "",
                        server_id or "",
                        sort_seq or "",
                    )
                    records.append(
                        {
                            "id": stable_id,
                            "package_id": package_id,
                            "source": "wechat",
                            "contact_id": normalize_contact_id(username),
                            "contact_name": contact_name,
                            "sender_name": sender_name or contact_name,
                            "is_self": is_self,
                            "sent_at": __import__("datetime").datetime.fromtimestamp(
                                sent_at
                            ).isoformat(),
                            "content": content,
                            "message_type": message_type,
                            "evidence_snippet": clip_snippet(content),
                            "source_file": source_db_map.get(db_path, db_path),
                        }
                    )
        finally:
            connection.close()

    records.sort(key=lambda item: (item["sent_at"], item["id"]))
    return records


def import_account(account_root, package_id):
    account_root = normalize_path(account_root)
    if not os.path.isdir(account_root):
        return {
            "ok": False,
            "error": "目录不存在：%s" % account_root,
            "warnings": [],
            "records": [],
            "discovered_files": [],
            "matched_account_root": account_root,
        }

    key_hex, diagnostics = find_db_key(account_root)
    if not key_hex:
        process_count = int(diagnostics.get("process_count") or 0)
        candidate_pids = diagnostics.get("candidate_pids", []) or []
        account_name = os.path.basename(account_root)
        if process_count <= 0:
            error = (
                "未检测到运行中的微信进程。请先打开电脑版微信并保持登录，"
                "再重新点击“直读微信本地数据库”。"
            )
            warnings = [
                "账号目录 %s 已找到，但当前电脑上没有运行中的 Weixin.exe / WeChat.exe。"
                % account_name
            ]
        elif not candidate_pids:
            error = (
                "检测到了正在运行的微信，但没有在进程里匹配到这份账号目录。"
                "请确认你选中的是当前登录账号对应的 xwechat_files 子目录。"
            )
            warnings = [
                "账号目录 %s 未匹配到当前登录中的微信进程，可能是登录了别的账号或目录选错了。"
                % account_name
            ]
        else:
            error = (
                "已检测到运行中的微信进程，但暂时没有从内存里提取出这份备份的解密 key。"
                "请保持微信停留在登录状态后重试。"
            )
            warnings = [
                "账号目录 %s 未能提取 key，当前仍需要微信保持登录后才能直读原始数据库。"
                % account_name
            ]
        return {
            "ok": False,
            "error": error,
            "warnings": warnings,
            "records": [],
            "discovered_files": [],
            "matched_account_root": account_root,
            "diagnostics": diagnostics,
        }

    temp_root = tempfile.mkdtemp(prefix="renmai_wechat_raw_")
    discovered_files = []
    try:
        decrypted_root, discovered_files, source_db_map = decrypt_required_dbs(
            account_root,
            key_hex,
            temp_root,
        )
        records = parse_messages(
            account_root,
            package_id,
            decrypted_root,
            source_db_map,
        )
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)

    if not records:
        return {
            "ok": False,
            "error": "已经找到解密 key，但没有从数据库里解析出可用聊天记录。",
            "warnings": [
                "账号目录 %s 已解密成功，但暂时没有识别出可导入消息。"
                % os.path.basename(account_root)
            ],
            "records": [],
            "discovered_files": discovered_files,
            "matched_account_root": account_root,
            "diagnostics": diagnostics,
        }

    return {
        "ok": True,
        "warnings": [
            "已从微信原始备份 %s 直读 %s 条聊天记录。"
            % (os.path.basename(account_root), len(records))
        ],
        "records": records,
        "discovered_files": discovered_files,
        "matched_account_root": account_root,
        "diagnostics": diagnostics,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-id", required=True)
    parser.add_argument("--account-root", action="append", default=[])
    parser.add_argument("--output-file")
    args = parser.parse_args()

    account_roots = []
    for item in args.account_root:
        normalized = normalize_path(item)
        if normalized not in account_roots:
            account_roots.append(normalized)

    if not account_roots:
        payload = {
            "ok": False,
            "error": "没有收到可解析的微信账号备份目录。",
        }
        if args.output_file:
            with open(args.output_file, "w", encoding="utf-8") as handle:
                json.dump(payload, handle, ensure_ascii=False)
            print(
                json.dumps(
                    {
                        "ok": False,
                        "output_file": args.output_file,
                    },
                    ensure_ascii=False,
                )
            )
        else:
            print(json.dumps(payload, ensure_ascii=False))
        return

    merged_records = []
    warnings = []
    discovered_files = []
    matched_account_roots = []
    errors = []

    for account_root in account_roots:
        result = import_account(account_root, args.package_id)
        warnings.extend(result.get("warnings", []))
        discovered_files.extend(result.get("discovered_files", []))
        matched_root = result.get("matched_account_root")
        if matched_root:
            matched_account_roots.append(matched_root)
        if result.get("ok"):
            merged_records.extend(result.get("records", []))
        else:
            error = result.get("error")
            if error:
                errors.append("%s：%s" % (os.path.basename(account_root), error))

    if not merged_records:
        payload = {
            "ok": False,
            "error": "；".join(errors) if errors else "未能从微信原始备份中提取出聊天记录。",
            "warnings": list(dict.fromkeys(warnings)),
            "discovered_files": list(dict.fromkeys(discovered_files)),
            "matched_account_roots": list(dict.fromkeys(matched_account_roots)),
        }
        if args.output_file:
            with open(args.output_file, "w", encoding="utf-8") as handle:
                json.dump(payload, handle, ensure_ascii=False)
            print(
                json.dumps(
                    {
                        "ok": False,
                        "output_file": args.output_file,
                    },
                    ensure_ascii=False,
                )
            )
        else:
            print(json.dumps(payload, ensure_ascii=False))
        return

    payload = {
        "ok": True,
        "warnings": list(dict.fromkeys(warnings)),
        "records": merged_records,
        "discovered_files": list(dict.fromkeys(discovered_files)),
        "matched_account_roots": list(dict.fromkeys(matched_account_roots)),
    }
    if args.output_file:
        with open(args.output_file, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False)
        print(
            json.dumps(
                {
                    "ok": True,
                    "output_file": args.output_file,
                    "record_count": len(merged_records),
                },
                ensure_ascii=False,
            )
        )
    else:
        print(json.dumps(payload, ensure_ascii=False))


def normalize_content(local_type, message_content, compress_content, media_meta=None):
    if media_meta and media_meta.get("content_override"):
        return media_meta.get("content_override", "")

    candidates = []
    for value in (message_content, compress_content):
        decoded = _decode_maybe_text(value)
        if decoded:
            candidates.append(decoded)

    text = candidates[0] if candidates else ""
    if looks_like_xml(text):
        simplified = simplify_xml_text(text)
        if simplified:
            text = simplified

    prefix_map = {
        3: "[图片]",
        34: "[语音]",
        43: "[视频]",
        47: "[表情]",
        49: "[文件/卡片]",
        10000: "[系统消息]",
    }
    prefix = prefix_map.get(local_type, "")
    if local_type == 1:
        return text if is_readable_plain_text(text) else "[不可直读消息]"
    if local_type not in prefix_map:
        prefix = "[消息类型 %s]" % local_type
    if text and is_readable_plain_text(text):
        return "%s\n%s" % (prefix, text) if prefix else text
    if prefix:
        return prefix
    return text or "[空消息]"


def _list_message_tables(connection):
    cursor = connection.cursor()
    cursor.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'Msg_%'"
    )
    table_names = [row[0] for row in cursor.fetchall() if row and row[0]]
    cursor.close()
    return table_names


def _iter_message_rows(connection, table_name, sender_column, include_packed_info):

    sender_expr = "'' AS sender_username"
    if sender_column:
        sender_expr = "Name2Id.%s AS sender_username" % sender_column
    packed_info_expr = "NULL AS packed_info_data"
    if include_packed_info:
        packed_info_expr = "msg.packed_info_data"

    sql = """
        SELECT
            msg.local_id,
            msg.server_id,
            msg.local_type,
            msg.sort_seq,
            %s,
            msg.create_time,
            msg.status,
            msg.source,
            msg.message_content,
            msg.compress_content,
            %s
        FROM %s AS msg
        LEFT JOIN Name2Id ON msg.real_sender_id = Name2Id.rowid
        ORDER BY msg.sort_seq
    """ % (
        sender_expr,
        packed_info_expr,
        table_name,
    )

    cursor = connection.cursor()
    cursor.execute(sql)
    try:
        while True:
            rows = cursor.fetchmany(512)
            if not rows:
                break
            for row in rows:
                yield row
    finally:
        cursor.close()


def parse_messages(account_root, package_id, decrypted_root, source_db_map, media_output_dir=None):
    contact_db_path = os.path.join(decrypted_root, "contact", "contact.db")
    session_db_path = os.path.join(decrypted_root, "session", "session.db")
    message_dir = os.path.join(decrypted_root, "message")

    contact_map, usernames = read_contact_map(contact_db_path)
    usernames.update(read_session_usernames(session_db_path))
    if not usernames:
        usernames.update(contact_map.keys())

    self_candidates = sanitize_account_username(account_root)
    username_by_table = {
        "Msg_%s" % hashlib.md5(username.encode("utf-8")).hexdigest(): username
        for username in usernames
    }
    if media_output_dir:
        message_resource_index, voice_index = _build_media_indices(decrypted_root)
    else:
        message_resource_index, voice_index = {}, {}
    attach_index_cache = {}
    warnings = []
    records = []

    if not os.path.isdir(message_dir):
        return records, warnings

    for name in sorted(os.listdir(message_dir)):
        if not re.match(r"message_\d+\.db$", name):
            continue
        db_path = os.path.join(message_dir, name)
        connection = sqlite3.connect(db_path)
        try:
            name2id_columns = (
                set(get_columns(connection, "Name2Id"))
                if table_exists(connection, "Name2Id")
                else set()
            )
            sender_column = None
            for candidate in ("user_name", "username"):
                if candidate in name2id_columns:
                    sender_column = candidate
                    break

            for table_name in _list_message_tables(connection):
                username = username_by_table.get(table_name)
                if not username:
                    continue
                table_columns = set(get_columns(connection, table_name))
                include_packed_info = "packed_info_data" in table_columns

                for row in _iter_message_rows(
                    connection,
                    table_name,
                    sender_column,
                    include_packed_info,
                ):
                    (
                        local_id,
                        server_id,
                        local_type,
                        sort_seq,
                        sender_username,
                        create_time,
                        _status,
                        _source_value,
                        message_content,
                        compress_content,
                        packed_info_data,
                    ) = row

                    sent_at = int(create_time or 0)
                    if sent_at <= 0:
                        continue

                    sender_username = (sender_username or "").strip()
                    is_self = sender_username in self_candidates
                    sender_name = "我" if is_self else contact_map.get(
                        sender_username,
                        sender_username or contact_map.get(username, username),
                    )
                    contact_name = contact_map.get(username, username)
                    local_type_value = int(local_type or 0)
                    stable_id = "%s_%s_%s_%s_%s" % (
                        os.path.basename(account_root),
                        username,
                        local_id or "",
                        server_id or "",
                        sort_seq or "",
                    )

                    media_meta = _build_media_metadata(
                        account_root,
                        username,
                        local_type_value,
                        local_id,
                        server_id,
                        message_content,
                        compress_content,
                        packed_info_data,
                        message_resource_index,
                        voice_index,
                        media_output_dir,
                        stable_id,
                        attach_index_cache,
                    )
                    warnings.extend(media_meta.get("warnings", []))

                    content = normalize_content(
                        local_type_value,
                        message_content,
                        compress_content,
                        media_meta=media_meta,
                    )
                    for candidate_prefix in (
                        "%s:\n" % sender_username,
                        "%s:" % sender_username,
                        "%s:\n" % username,
                        "%s:" % username,
                    ):
                        if candidate_prefix.strip() and content.startswith(candidate_prefix):
                            content = content[len(candidate_prefix) :].lstrip()
                            break

                    records.append(
                        {
                            "id": stable_id,
                            "package_id": package_id,
                            "source": "wechat",
                            "contact_id": normalize_contact_id(username),
                            "contact_name": contact_name,
                            "sender_name": sender_name or contact_name,
                            "is_self": is_self,
                            "sent_at": __import__("datetime").datetime.fromtimestamp(
                                sent_at
                            ).isoformat(),
                            "content": content,
                            "message_type": guess_message_type(local_type_value),
                            "evidence_snippet": clip_snippet(content),
                            "source_file": source_db_map.get(db_path, db_path),
                            "attachment_path": media_meta.get("attachment_path", ""),
                        }
                    )
        finally:
            connection.close()

    records.sort(key=lambda item: (item["sent_at"], item["id"]))
    return records, list(dict.fromkeys(warnings))


def import_account(account_root, package_id, media_output_dir=None):
    account_root = normalize_path(account_root)
    if not os.path.isdir(account_root):
        return {
            "ok": False,
            "error": "目录不存在：%s" % account_root,
            "warnings": [],
            "records": [],
            "discovered_files": [],
            "matched_account_root": account_root,
        }

    key_hex, diagnostics = find_db_key(account_root)
    if not key_hex:
        process_count = int(diagnostics.get("process_count") or 0)
        candidate_pids = diagnostics.get("candidate_pids", []) or []
        account_name = os.path.basename(account_root)
        if process_count <= 0:
            error = (
                "没有检测到运行中的微信进程。请先打开电脑版微信并保持登录，"
                "再重新点击“直读微信本地数据库”。"
            )
            warnings = [
                "账号目录 %s 已找到，但当前电脑上没有运行中的 Weixin.exe / WeChat.exe。"
                % account_name
            ]
        elif not candidate_pids:
            error = (
                "检测到了正在运行的微信，但没有在进程里匹配到这份账号目录。"
                "请确认你选中的是当前登录账号对应的 xwechat_files 子目录。"
            )
            warnings = [
                "账号目录 %s 未匹配到当前登录中的微信进程，可能是登录了别的账号或目录选错了。"
                % account_name
            ]
        else:
            error = (
                "已经检测到运行中的微信进程，但暂时没有从内存里提取出这份备份的解密 key。"
                "请保持微信停留在登录状态后重试。"
            )
            warnings = [
                "账号目录 %s 未能提取 key，当前仍需要微信保持登录后才能直读原始数据库。"
                % account_name
            ]
        return {
            "ok": False,
            "error": error,
            "warnings": warnings,
            "records": [],
            "discovered_files": [],
            "matched_account_root": account_root,
            "diagnostics": diagnostics,
        }

    temp_root = tempfile.mkdtemp(prefix="renmai_wechat_raw_")
    discovered_files = []
    warnings = []
    try:
        decrypted_root, discovered_files, source_db_map = decrypt_required_dbs(
            account_root,
            key_hex,
            temp_root,
            include_media=bool(media_output_dir),
        )
        records, parse_warnings = parse_messages(
            account_root,
            package_id,
            decrypted_root,
            source_db_map,
            media_output_dir=media_output_dir,
        )
        warnings.extend(parse_warnings)
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)

    if not records:
        warnings.append(
            "账号目录 %s 已解密成功，但暂时没有识别出可导入消息。"
            % os.path.basename(account_root)
        )
        return {
            "ok": False,
            "error": "已经找到解密 key，但没有从数据库里解析出可用聊天记录。",
            "warnings": list(dict.fromkeys(warnings)),
            "records": [],
            "discovered_files": discovered_files,
            "matched_account_root": account_root,
            "diagnostics": diagnostics,
        }

    warnings.append(
        "已从微信原始备份 %s 直读 %s 条聊天记录。"
        % (os.path.basename(account_root), len(records))
    )
    return {
        "ok": True,
        "warnings": list(dict.fromkeys(warnings)),
        "records": records,
        "discovered_files": discovered_files,
        "matched_account_root": account_root,
        "diagnostics": diagnostics,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-id", required=True)
    parser.add_argument("--account-root", action="append", default=[])
    parser.add_argument("--output-file")
    parser.add_argument("--media-output-dir")
    args = parser.parse_args()

    account_roots = []
    for item in args.account_root:
        normalized = normalize_path(item)
        if normalized not in account_roots:
            account_roots.append(normalized)

    if not account_roots:
        payload = {
            "ok": False,
            "error": "没有收到可解析的微信账号备份目录。",
        }
        if args.output_file:
            with open(args.output_file, "w", encoding="utf-8") as handle:
                json.dump(payload, handle, ensure_ascii=False)
            print(
                json.dumps(
                    {
                        "ok": False,
                        "output_file": args.output_file,
                    },
                    ensure_ascii=False,
                )
            )
        else:
            print(json.dumps(payload, ensure_ascii=False))
        return

    merged_records = []
    warnings = []
    discovered_files = []
    matched_account_roots = []
    errors = []

    for account_root in account_roots:
        result = import_account(
            account_root,
            args.package_id,
            media_output_dir=args.media_output_dir,
        )
        warnings.extend(result.get("warnings", []))
        discovered_files.extend(result.get("discovered_files", []))
        matched_root = result.get("matched_account_root")
        if matched_root:
            matched_account_roots.append(matched_root)
        if result.get("ok"):
            merged_records.extend(result.get("records", []))
        else:
            error = (result.get("error") or "").strip()
            if error:
                errors.append("%s：%s" % (os.path.basename(account_root), error))

    if not merged_records:
        payload = {
            "ok": False,
            "error": "；".join(errors) if errors else "未能从微信原始备份中提取出聊天记录。",
            "warnings": list(dict.fromkeys(warnings)),
            "discovered_files": list(dict.fromkeys(discovered_files)),
            "matched_account_roots": list(dict.fromkeys(matched_account_roots)),
        }
        if args.output_file:
            with open(args.output_file, "w", encoding="utf-8") as handle:
                json.dump(payload, handle, ensure_ascii=False)
            print(
                json.dumps(
                    {
                        "ok": False,
                        "output_file": args.output_file,
                    },
                    ensure_ascii=False,
                )
            )
        else:
            print(json.dumps(payload, ensure_ascii=False))
        return

    payload = {
        "ok": True,
        "warnings": list(dict.fromkeys(warnings)),
        "records": merged_records,
        "discovered_files": list(dict.fromkeys(discovered_files)),
        "matched_account_roots": list(dict.fromkeys(matched_account_roots)),
    }
    if args.output_file:
        with open(args.output_file, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False)
        print(
            json.dumps(
                {
                    "ok": True,
                    "output_file": args.output_file,
                    "record_count": len(merged_records),
                },
                ensure_ascii=False,
            )
        )
    else:
        print(json.dumps(payload, ensure_ascii=False))


def _emit_cli_result(args, payload):
    if args.output_file:
        with open(args.output_file, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False)
        if not getattr(args, "quiet", False):
            status = {
                "ok": bool(payload.get("ok")),
                "output_file": args.output_file,
            }
            if payload.get("ok"):
                status["record_count"] = len(payload.get("records", []))
            print(json.dumps(status, ensure_ascii=False))
        return

    print(json.dumps(payload, ensure_ascii=False))


def _build_missing_key_message(account_root, original_message):
    basename = os.path.basename(account_root)
    if "message_" in original_message and ("key" in original_message.lower() or "解密" in original_message):
        return (
            "账号目录 %s 的消息库没有拿到完整解密 key。"
            "这通常是因为当前登录微信账号与所选备份不一致，或者微信没有保持登录。"
            "请确认选中的是当前账号对应的 xwechat_files，并在电脑微信保持登录时重试。"
        ) % basename
    return (
        "账号目录 %s 无法完成数据库解密：%s"
        % (basename, original_message or "未知错误")
    )


def import_account(account_root, package_id, media_output_dir=None):
    account_root = normalize_path(account_root)
    if not os.path.isdir(account_root):
        return {
            "ok": False,
            "error": "目录不存在：%s" % account_root,
            "warnings": [],
            "records": [],
            "discovered_files": [],
            "matched_account_root": account_root,
        }

    key_hex, diagnostics = find_db_key(account_root)
    if not key_hex:
        process_count = int(diagnostics.get("process_count") or 0)
        candidate_pids = diagnostics.get("candidate_pids", []) or []
        account_name = os.path.basename(account_root)
        if process_count <= 0:
            error = "未检测到正在运行的微信进程。请先打开电脑微信并保持登录，再重新尝试直读微信本地数据库。"
            warnings = [
                "账号目录 %s 已找到，但当前电脑上没有运行中的 Weixin.exe / WeChat.exe。"
                % account_name
            ]
        elif not candidate_pids:
            error = (
                "检测到正在运行的微信，但没有在进程里匹配到这份账号目录。"
                "请确认选中的是当前登录账号对应的 xwechat_files 子目录。"
            )
            warnings = [
                "账号目录 %s 未匹配到当前登录中的微信进程，可能登录了其他账号或目录选错。"
                % account_name
            ]
        else:
            error = (
                "已检测到正在运行的微信进程，但暂时没有从内存里提取出这份备份的解密 key。"
                "请保持微信停留在登录状态后再试。"
            )
            warnings = [
                "账号目录 %s 未能提取 key，当前仍需要微信保持登录后才能直读原始数据库。"
                % account_name
            ]
        return {
            "ok": False,
            "error": error,
            "warnings": warnings,
            "records": [],
            "discovered_files": [],
            "matched_account_root": account_root,
            "diagnostics": diagnostics,
        }

    temp_root = tempfile.mkdtemp(prefix="renmai_wechat_raw_")
    discovered_files = []
    warnings = []
    records = []
    try:
        try:
            decrypted_root, discovered_files, source_db_map = decrypt_required_dbs(
                account_root,
                key_hex,
                temp_root,
                include_media=bool(media_output_dir),
            )
        except Exception as exc:
            message = str(exc).strip()
            lower = message.lower()
            if "缺少" in message and ("解密" in message or "key" in lower):
                error = _build_missing_key_message(account_root, message)
            elif "校验失败" in message or "decrypt" in lower:
                error = (
                    "微信数据库解密校验失败，当前拿到的 key 与这份备份不匹配。"
                    "请确认账号目录正确，并在电脑微信保持登录后重试。"
                )
            else:
                error = "读取微信原始备份失败：%s" % (message or "未知错误")
            return {
                "ok": False,
                "error": error,
                "warnings": warnings,
                "records": [],
                "discovered_files": discovered_files,
                "matched_account_root": account_root,
                "diagnostics": diagnostics,
            }

        try:
            records, parse_warnings = parse_messages(
                account_root,
                package_id,
                decrypted_root,
                source_db_map,
                media_output_dir=media_output_dir,
            )
        except Exception as exc:
            message = str(exc).strip() or "未知错误"
            return {
                "ok": False,
                "error": "数据库已解密，但解析消息失败：%s" % message,
                "warnings": warnings,
                "records": [],
                "discovered_files": discovered_files,
                "matched_account_root": account_root,
                "diagnostics": diagnostics,
            }

        warnings.extend(parse_warnings)
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)

    if not records:
        warnings.append(
            "账号目录 %s 已解密成功，但暂时没有识别出可导入消息。"
            % os.path.basename(account_root)
        )
        return {
            "ok": False,
            "error": "已经找到解密 key，但没有从数据库里解析出可用聊天记录。",
            "warnings": list(dict.fromkeys(warnings)),
            "records": [],
            "discovered_files": discovered_files,
            "matched_account_root": account_root,
            "diagnostics": diagnostics,
        }

    warnings.append(
        "已从微信原始备份 %s 直读 %s 条聊天记录。"
        % (os.path.basename(account_root), len(records))
    )
    return {
        "ok": True,
        "warnings": list(dict.fromkeys(warnings)),
        "records": records,
        "discovered_files": discovered_files,
        "matched_account_root": account_root,
        "diagnostics": diagnostics,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-id", required=True)
    parser.add_argument("--account-root", action="append", default=[])
    parser.add_argument("--output-file")
    parser.add_argument("--media-output-dir")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    account_roots = []
    for item in args.account_root:
        normalized = normalize_path(item)
        if normalized not in account_roots:
            account_roots.append(normalized)

    if not account_roots:
        _emit_cli_result(
            args,
            {
                "ok": False,
                "error": "没有收到可解析的微信账号备份目录。",
            },
        )
        return

    merged_records = []
    warnings = []
    discovered_files = []
    matched_account_roots = []
    errors = []

    for account_root in account_roots:
        result = import_account(
            account_root,
            args.package_id,
            media_output_dir=args.media_output_dir,
        )
        warnings.extend(result.get("warnings", []))
        discovered_files.extend(result.get("discovered_files", []))
        matched_root = result.get("matched_account_root")
        if matched_root:
            matched_account_roots.append(matched_root)
        if result.get("ok"):
            merged_records.extend(result.get("records", []))
        else:
            error = (result.get("error") or "").strip()
            if error:
                errors.append("%s：%s" % (os.path.basename(account_root), error))

    if not merged_records:
        _emit_cli_result(
            args,
            {
                "ok": False,
                "error": "; ".join(errors)
                if errors
                else "未能从微信原始备份中提取出聊天记录。",
                "warnings": list(dict.fromkeys(warnings)),
                "discovered_files": list(dict.fromkeys(discovered_files)),
                "matched_account_roots": list(dict.fromkeys(matched_account_roots)),
            },
        )
        return

    _emit_cli_result(
        args,
        {
            "ok": True,
            "warnings": list(dict.fromkeys(warnings)),
            "records": merged_records,
            "discovered_files": list(dict.fromkeys(discovered_files)),
            "matched_account_roots": list(dict.fromkeys(matched_account_roots)),
        },
    )

def _error_payload(code, detail=None):
    if detail:
        return "%s:%s" % (code, detail)
    return code


def _build_missing_key_message(account_root, original_message):
    basename = os.path.basename(account_root)
    if "message_" in original_message and ("key" in original_message.lower() or "解密" in original_message):
        return _error_payload("RENMAI_ERR_MISSING_DB_KEY", basename)
    return _error_payload("RENMAI_ERR_DECRYPT_FAILED", basename)


def import_account(account_root, package_id, media_output_dir=None):
    account_root = normalize_path(account_root)
    if not os.path.isdir(account_root):
        return {
            "ok": False,
            "error": _error_payload("RENMAI_ERR_DIRECTORY_NOT_FOUND", account_root),
            "warnings": [],
            "records": [],
            "discovered_files": [],
            "matched_account_root": account_root,
        }

    key_hex, diagnostics = find_db_key(account_root)
    if not key_hex:
        process_count = int(diagnostics.get("process_count") or 0)
        candidate_pids = diagnostics.get("candidate_pids", []) or []
        if process_count <= 0:
            error = "RENMAI_ERR_WECHAT_NOT_RUNNING"
        elif not candidate_pids:
            error = "RENMAI_ERR_ACCOUNT_MISMATCH"
        else:
            error = "RENMAI_ERR_KEY_UNAVAILABLE"
        return {
            "ok": False,
            "error": error,
            "warnings": [],
            "records": [],
            "discovered_files": [],
            "matched_account_root": account_root,
            "diagnostics": diagnostics,
        }

    temp_root = tempfile.mkdtemp(prefix="renmai_wechat_raw_")
    discovered_files = []
    warnings = []
    records = []
    try:
        try:
            decrypted_root, discovered_files, source_db_map = decrypt_required_dbs(
                account_root,
                key_hex,
                temp_root,
                include_media=bool(media_output_dir),
            )
        except Exception as exc:
            return {
                "ok": False,
                "error": _build_missing_key_message(account_root, str(exc).strip()),
                "warnings": warnings,
                "records": [],
                "discovered_files": discovered_files,
                "matched_account_root": account_root,
                "diagnostics": diagnostics,
            }

        try:
            records, parse_warnings = parse_messages(
                account_root,
                package_id,
                decrypted_root,
                source_db_map,
                media_output_dir=media_output_dir,
            )
        except Exception as exc:
            return {
                "ok": False,
                "error": _error_payload("RENMAI_ERR_PARSE_MESSAGES", str(exc).strip() or "unknown"),
                "warnings": warnings,
                "records": [],
                "discovered_files": discovered_files,
                "matched_account_root": account_root,
                "diagnostics": diagnostics,
            }

        warnings.extend(parse_warnings)
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)

    if not records:
        return {
            "ok": False,
            "error": "RENMAI_ERR_NO_RECORDS_AFTER_DECRYPT",
            "warnings": list(dict.fromkeys(warnings)),
            "records": [],
            "discovered_files": discovered_files,
            "matched_account_root": account_root,
            "diagnostics": diagnostics,
        }

    warnings.append(
        "Imported %s chat records from raw backup %s."
        % (len(records), os.path.basename(account_root))
    )
    return {
        "ok": True,
        "warnings": list(dict.fromkeys(warnings)),
        "records": records,
        "discovered_files": discovered_files,
        "matched_account_root": account_root,
        "diagnostics": diagnostics,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package-id", required=True)
    parser.add_argument("--account-root", action="append", default=[])
    parser.add_argument("--output-file")
    parser.add_argument("--media-output-dir")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    account_roots = []
    for item in args.account_root:
        normalized = normalize_path(item)
        if normalized not in account_roots:
            account_roots.append(normalized)

    if not account_roots:
        _emit_cli_result(
            args,
            {
                "ok": False,
                "error": "RENMAI_ERR_NO_ACCOUNT_ROOTS",
            },
        )
        return

    merged_records = []
    warnings = []
    discovered_files = []
    matched_account_roots = []
    errors = []

    for account_root in account_roots:
        result = import_account(
            account_root,
            args.package_id,
            media_output_dir=args.media_output_dir,
        )
        warnings.extend(result.get("warnings", []))
        discovered_files.extend(result.get("discovered_files", []))
        matched_root = result.get("matched_account_root")
        if matched_root:
            matched_account_roots.append(matched_root)
        if result.get("ok"):
            merged_records.extend(result.get("records", []))
        else:
            error = (result.get("error") or "").strip()
            if error:
                errors.append("%s: %s" % (os.path.basename(account_root), error))

    if not merged_records:
        _emit_cli_result(
            args,
            {
                "ok": False,
                "error": "; ".join(errors)
                if errors
                else "RENMAI_ERR_NO_RAW_RECORDS",
                "warnings": list(dict.fromkeys(warnings)),
                "discovered_files": list(dict.fromkeys(discovered_files)),
                "matched_account_roots": list(dict.fromkeys(matched_account_roots)),
            },
        )
        return

    _emit_cli_result(
        args,
        {
            "ok": True,
            "warnings": list(dict.fromkeys(warnings)),
            "records": merged_records,
            "discovered_files": list(dict.fromkeys(discovered_files)),
            "matched_account_roots": list(dict.fromkeys(matched_account_roots)),
        },
    )


if __name__ == "__main__":
    main()
