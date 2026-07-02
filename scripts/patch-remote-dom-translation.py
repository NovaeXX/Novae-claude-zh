import argparse
import importlib.util
import json
import re
from pathlib import Path


MARKER = "WIN_CC_ZH_CN_REMOTE_DOM_TRANSLATION_V1"
TARGET_PATH = ".vite/build/mainView.js"


MANUAL_TRANSLATIONS = {
    "New chat": "新对话",
    "Recents": "最近",
    "Projects": "项目",
    "Artifacts": "作品",
    "Chats": "对话",
    "Search": "搜索",
    "Settings": "设置",
    "Help": "帮助",
    "Upgrade": "升级",
    "Plan": "计划",
    "Profile": "个人资料",
    "Log out": "退出登录",
    "Sign out": "退出登录",
    "What can I help you with?": "我能帮你什么？",
    "Write a message...": "输入消息...",
    "Write a message…": "输入消息...",
    "Attach files": "附加文件",
    "Send message": "发送消息",
    "Claude can make mistakes. Please double-check responses.": "Claude 可能会出错，请仔细核对回复。",
    "No chats yet": "还没有对话",
    "Today": "今天",
    "Yesterday": "昨天",
    "Continue": "继续",
    "Cancel": "取消",
    "Save": "保存",
    "Delete": "删除",
    "Rename": "重命名",
    "Share": "分享",
    "Copy": "复制",
    "Retry": "重试",
    "Edit": "编辑",
    "Done": "完成",
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load_json_if_exists(path: Path):
    if not path.exists():
        return {}
    raw = path.read_text(encoding="utf-8-sig")
    if not raw.strip():
        return {}
    return json.loads(raw)


def has_cjk(value: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", value))


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def load_remote_overrides(path: Path) -> dict[str, str]:
    data = load_json_if_exists(path)
    overrides: dict[str, str] = {}
    if not data:
        return overrides

    if isinstance(data, dict):
        iterable = data.items()
    elif isinstance(data, list):
        iterable = []
        for item in data:
            if isinstance(item, dict):
                source = item.get("source") or item.get("en") or item.get("key")
                target = item.get("target") or item.get("zh") or item.get("translation") or item.get("suggested")
                iterable.append((source, target))
    else:
        iterable = []

    for source, target in iterable:
        if isinstance(target, dict):
            target = target.get("target") or target.get("zh") or target.get("translation") or target.get("suggested")
        if not isinstance(source, str) or not isinstance(target, str):
            continue
        source = normalize_text(source)
        target = normalize_text(target)
        keep_identity = source == target and re.search(r"\b(Windows|macOS|iOS|Android)\b", source)
        if not source or not target or (source == target and not keep_identity):
            continue
        if not has_cjk(target) and not has_cjk(source) and not keep_identity:
            continue
        overrides[source] = target

    return overrides


def load_remote_fragments(path: Path) -> dict[str, str]:
    fragments = load_remote_overrides(path)
    return {
        source: target
        for source, target in fragments.items()
        if is_phrase_candidate(source, 220)
    }


def latest_original_frontend_en(backup_dir: Path, app_dir: Path) -> Path:
    # Locale shadow backups keep the original en-US file before it is overwritten
    # with zh-CN. The file with the fewest CJK characters is the safest source.
    candidates = []
    for path in backup_dir.glob("locale-shadow/*/frontend/en-US.json"):
        raw = path.read_text(encoding="utf-8-sig", errors="replace")
        cjk_count = len(re.findall(r"[\u4e00-\u9fff]", raw))
        candidates.append((cjk_count, -len(raw), path))
    if not candidates:
        current_en = app_dir / "resources" / "ion-dist" / "i18n" / "en-US.json"
        if current_en.exists():
            return current_en
        raise SystemExit(
            f"Cannot find original frontend en-US resource under {backup_dir / 'locale-shadow'} "
            f"or {current_en}"
        )
    candidates.sort()
    return candidates[0][2]


def is_phrase_candidate(source: str, max_len: int) -> bool:
    return 2 <= len(source) <= max_len and "{" not in source and "<" not in source and "\n" not in source


def build_translation_pairs(config: dict) -> tuple[dict[str, str], list[tuple[str, str]], list[tuple[str, str]], Path, int, int]:
    backup_dir = Path(config["backupDir"])
    app_dir = Path(config["portableClaudeDir"])
    overrides_dir = Path(config["overridesDir"])
    en_path = latest_original_frontend_en(backup_dir, app_dir)
    zh_path = app_dir / "resources" / "ion-dist" / "i18n" / "zh-CN.json"
    if not zh_path.exists():
        raise SystemExit(f"Missing zh-CN frontend resource: {zh_path}")

    en = load_json(en_path)
    zh = load_json(zh_path)
    exact = {}

    # Start with official i18n pairs, then layer confirmed local overrides.
    for key, source in en.items():
        target = zh.get(key)
        if not isinstance(source, str) or not isinstance(target, str):
            continue
        source = normalize_text(source)
        target = normalize_text(target)
        if not source or not target or source == target or not has_cjk(target):
            continue
        if len(source) > 420 or len(target) > 520:
            continue
        exact.setdefault(source, target)

    remote_overrides = load_remote_overrides(overrides_dir / "remote-dom-zh-CN.override.json")
    remote_fragments = load_remote_fragments(overrides_dir / "remote-dom-fragments-zh-CN.override.json")

    for source, target in MANUAL_TRANSLATIONS.items():
        exact[source] = target

    for source, target in remote_overrides.items():
        exact[source] = target

    priority_phrase = []
    priority_seen = set()
    for source, target in {**MANUAL_TRANSLATIONS, **remote_overrides}.items():
        if is_phrase_candidate(source, 500):
            priority_phrase.append((source, target))
            priority_seen.add(source)
    priority_phrase.sort(key=lambda item: len(item[0]), reverse=True)

    base_phrase = []
    for source, target in exact.items():
        if source in priority_seen:
            continue
        if is_phrase_candidate(source, 90):
            base_phrase.append((source, target))
    base_phrase.sort(key=lambda item: len(item[0]), reverse=True)

    remaining = max(0, 3000 - len(priority_phrase))
    phrase = priority_phrase + base_phrase[:remaining]

    fragments = list(remote_fragments.items())
    fragments.sort(key=lambda item: len(item[0]), reverse=True)

    return exact, phrase[:3000], fragments, en_path, len(remote_overrides), len(remote_fragments)


def make_snippet(exact: dict[str, str], phrase: list[tuple[str, str]], fragments: list[tuple[str, str]], pending_path: Path) -> str:
    # The injected script runs inside Claude Desktop's remote page preload. Keep it
    # self-contained and conservative: exact match first, phrase match second,
    # fragment match last, then record still-English text for human review.
    exact_json = json.dumps(exact, ensure_ascii=False, separators=(",", ":"))
    phrase_json = json.dumps(phrase, ensure_ascii=False, separators=(",", ":"))
    fragment_json = json.dumps(fragments, ensure_ascii=False, separators=(",", ":"))
    pending_path_json = json.dumps(str(pending_path), ensure_ascii=False)
    return f'''
;(()=>{{const MARK="{MARKER}";if(globalThis[MARK])return;globalThis[MARK]=true;
try{{Object.defineProperty(Navigator.prototype,"language",{{get:()=>"zh-CN",configurable:true}});Object.defineProperty(Navigator.prototype,"languages",{{get:()=>["zh-CN","zh","en-US","en"],configurable:true}});}}catch{{}}
try{{localStorage.setItem("locale","zh-CN");localStorage.setItem("language","zh-CN");}}catch{{}}
const exact={exact_json};
const phrases={phrase_json};
const fragments={fragment_json};
const pendingPath={pending_path_json};
const pendingKey="WIN_CC_ZH_CN_PENDING_REMOTE_DOM_V1";
const norm=s=>String(s??"").replace(/\\s+/g," ").trim();
const canon=s=>norm(s).replace(/[‘’]/g,"'").replace(/[“”]/g,'"').replace(/…/g,"...").replace(/[－–—]/g,"-").replace(/\\s+([,.!?;:])/g,"$1");
const preserve=(oldText,newText)=>{{const a=String(oldText).match(/^\\s*/)?.[0]||"";const b=String(oldText).match(/\\s*$/)?.[0]||"";return a+newText+b}};
const exactCanon=Object.create(null);const exactCanonLower=Object.create(null);for(const k of Object.keys(exact)){{const c=canon(k);exactCanon[c]=exact[k];exactCanonLower[c.toLowerCase()]=exact[k];}}
const pending=new Set();
const loadPending=()=>{{try{{for(const x of JSON.parse(localStorage.getItem(pendingKey)||"[]"))if(typeof x==="string")pending.add(x);}}catch{{}}}};
const savePending=()=>{{const arr=[...pending].sort();try{{localStorage.setItem(pendingKey,JSON.stringify(arr));}}catch{{}}try{{const req=globalThis.require||globalThis.window?.require;if(req){{const fs=req("fs");const path=req("path");fs.mkdirSync(path.dirname(pendingPath),{{recursive:true}});fs.writeFileSync(pendingPath,JSON.stringify(arr,null,2),"utf8");}}}}catch{{}}}};
const knownWords=/\\b(Claude Code|Claude|Anthropic|MCP|Node\\.js|JavaScript|TypeScript|GitHub|Git|PR|CI|IDE|CLI|API|URL|JSON|HTML|CSS|HTTP|HTTPS|OAuth|Cowork|Artifact|Artifacts|Skills|Connectors)\\b/gi;
const hasMeaningfulEnglish=s=>{{let rest=norm(s).replace(knownWords,"");rest=rest.replace(/[\\u4e00-\\u9fff\\s。、，（）()：:；;！!？?'"“”‘’\\-—/.0-9]+/g,"");return /[A-Za-z]{{3,}}/.test(rest);}};
const track=s=>{{const n=norm(s);if(!n||n.length<2||n.length>500)return;if(!/[A-Za-z]/.test(n))return;if(/^(https?|claude):\\/\\//i.test(n)||/^[A-Z0-9_\\-./:]+$/.test(n))return;if(!hasMeaningfulEnglish(n))return;if(!pending.has(n)){{pending.add(n);try{{console.info("[CLAUDE_ZH_PENDING_TRANSLATION]",n);}}catch{{}}savePending();}}}};
loadPending();
globalThis.__claudeZhPendingTranslations=()=>[...pending].sort();
const lookup=s=>{{const n=norm(s);if(Object.prototype.hasOwnProperty.call(exact,n))return exact[n];const c=canon(n);return exactCanon[c]||exactCanonLower[c.toLowerCase()];}};
const applyPairs=(value,pairs)=>{{let out=String(value);for(const [a,b] of pairs)if(out.includes(a))out=out.split(a).join(b);return out;}};
const tx=s=>{{if(!s)return s;const n=norm(s);let v=lookup(n);if(v)return preserve(s,v);if(n.length<700){{let out=String(s);out=applyPairs(out,phrases);out=applyPairs(out,fragments);if(out!==String(s)){{track(out);return out;}}}}track(n);return s;}};
const shouldSkip=el=>!el||["SCRIPT","STYLE","NOSCRIPT","TEXTAREA","CODE","PRE"].includes(el.tagName);
const walk=root=>{{if(!root)return;try{{
  const doc=root.ownerDocument||document;
  for(const el of root.querySelectorAll?.("*")||[])if(el.shadowRoot)walk(el.shadowRoot);
  const tw=doc.createTreeWalker(root,NodeFilter.SHOW_TEXT,{{acceptNode:n=>{{const p=n.parentElement;if(shouldSkip(p))return NodeFilter.FILTER_REJECT;const t=n.nodeValue||"";return /[A-Za-z]/.test(t)?NodeFilter.FILTER_ACCEPT:NodeFilter.FILTER_SKIP;}}}});
  for(let n;n=tw.nextNode();){{const v=tx(n.nodeValue);if(v!==n.nodeValue)n.nodeValue=v;}}
  for(const el of root.querySelectorAll?.("input,textarea,button,img,[aria-label],[aria-description],[title],[alt],[placeholder],[data-tooltip],[data-title]")||[])for(const attr of ["placeholder","aria-label","aria-description","title","alt","data-tooltip","data-title"]){{const v=el.getAttribute?.(attr);if(v&&/[A-Za-z]/.test(v)){{const nv=tx(v);if(nv!==v)el.setAttribute(attr,nv);}}}}
}}catch{{}}}};
const run=()=>walk(document.body||document.documentElement);
addEventListener("DOMContentLoaded",run,{{once:true}});for(const d of [50,250,800,1600,3000,6000])setTimeout(run,d);
const watch=()=>{{const r=document.documentElement||document.body;if(!r){{setTimeout(watch,50);return}}try{{new MutationObserver(ms=>{{for(const m of ms){{if(m.type==="characterData")walk(m.target.parentElement);for(const n of m.addedNodes)walk(n.nodeType===1?n:n.parentElement);}}}}).observe(r,{{childList:true,subtree:true,characterData:true}});run();}}catch{{setTimeout(watch,200)}}}};
watch();
}})();
'''


def remove_existing_snippet(text: str) -> str:
    start = text.find(f';(()=>{{const MARK="{MARKER}"')
    if start < 0:
        return text
    end = text.find("\n})();", start)
    if end < 0:
        return text
    return text[:start] + text[end + len("\n})();") :]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    args = parser.parse_args()

    config_path = Path(args.config)
    config = load_json(config_path)
    patch_script_value = config.get("patchScript")
    if not patch_script_value:
        raise SystemExit("Missing patch script path in config. Set patchScript in config/paths.local.json.")
    patch_script = Path(patch_script_value)
    app_dir = Path(config["portableClaudeDir"])
    asar = app_dir / "resources" / "app.asar"
    reports_dir = Path(config.get("projectRoot", config_path.parent.parent)) / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    pending_path = reports_dir / "runtime-remote-dom-pending.json"

    spec = importlib.util.spec_from_file_location("claude_zh_patch_tool", patch_script)
    patch_tool = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(patch_tool)

    exact, phrase, fragments, source_en, remote_override_count, remote_fragment_count = build_translation_pairs(config)
    snippet = make_snippet(exact, phrase, fragments, pending_path)

    def patcher(content: bytes) -> bytes:
        text = content.decode("utf-8")
        text = remove_existing_snippet(text)
        marker = "\n//# sourceMappingURL=mainView.js.map"
        if marker not in text:
            raise SystemExit("Cannot find mainView.js source map marker.")
        return text.replace(marker, snippet + marker, 1).encode("utf-8")

    data = asar.read_bytes()
    old_hash = patch_tool.asar_header_hash(data)
    try:
        backup = patch_tool.backup_file(asar, "before-remote-dom-zh-CN")
        changed, previous_hash, new_hash = patch_tool.patch_asar_file_bytes(asar, TARGET_PATH, patcher)
    except PermissionError as exc:
        raise SystemExit(
            "Access denied while patching app.asar. Fully close Claude, then run this script "
            "from your own PowerShell window. Original error: " + str(exc)
        )
    except Exception:
        if "backup" in locals() and backup.exists():
            import shutil

            shutil.copy2(backup, asar)
        raise

    if changed:
        patch_tool.patch_exe_asar_header_hash(
            app_dir,
            new_hash,
            [previous_hash, old_hash, *patch_tool.backup_header_hashes(asar)],
            "before-remote-dom-zh-CN",
        )

    print(f"Remote DOM translation source: {source_en}")
    print(f"Injected exact translations: {len(exact)}")
    print(f"Injected phrase translations: {len(phrase)}")
    print(f"Injected fragment translations: {len(fragments)}")
    print(f"Remote override translations: {remote_override_count}")
    print(f"Remote fragment translations: {remote_fragment_count}")
    print(f"Runtime pending translations: {pending_path}")
    print(f"Backed up app.asar: {backup}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
