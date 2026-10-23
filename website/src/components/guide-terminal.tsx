"use client";

import { useEffect, useRef, useState } from "react";

type Leaf = {
  en: string;
  zh: string;
  command: string | null;
  body: string;
  bodyZh?: string;
  before?: { en: string; zh: string };
};

type Group = { en: string; zh: string; items: Leaf[] };

const ver = "v20.11.0";
const home = "/home/user";
const root = `${home}/.nvm`;

function installBody(version: string) {
  return [
    `Installing ${version} (x64)...`,
    "Extracting...",
    `Installed ${version}`,
    `default -> ${version}`,
    `Now using node ${version} (npm v10.8.2)`,
  ].join("\n");
}

const menu: Group[] = [
  {
    en: "Install Node",
    zh: "安装 Node",
    items: [
      { en: "Install latest LTS", zh: "装最新 LTS", command: "nvm install --lts", body: installBody("v24.22.1") },
      { en: "Install latest Current", zh: "装最新 Current", command: "nvm install node", body: installBody("v26.12.1") },
      {
        en: "Enter a version (20.18.0 / lts/hydrogen)",
        zh: "输入具体版本(如 20.18.0 / lts/hydrogen)",
        command: "nvm install <version>",
        before: {
          en: "Version (for example 20.18.0 or lts/hydrogen)\n\n> 20.18.0",
          zh: "版本(例如 20.18.0 或 lts/hydrogen)\n\n> 20.18.0",
        },
        body: installBody("v20.18.0"),
      },
      {
        en: "Pick from the remote list, then install",
        zh: "从远程列表里选一个再装",
        command: "nvm install <version>",
        before: {
          en: "Fetching the remote list...\n\n  1  v26.12.1\n  2  v26.12.0\n  0  Back\n\n> 1",
          zh: "正在获取远程列表...\n\n  1  v26.12.1\n  2  v26.12.0\n  0  返回\n\n> 1",
        },
        body: installBody("v26.12.1"),
      },
    ],
  },
  {
    en: "Switch version (use)",
    zh: "切换版本(use)",
    items: [
      {
        en: "Choose an installed version",
        zh: "选已安装版本",
        command: "nvm use <version>",
        before: { en: `  1  ${ver}\n  0  Back\n\n> 1`, zh: `  1  ${ver}\n  0  返回\n\n> 1` },
        body: `Now using node ${ver} (npm v10.8.2)`,
      },
      {
        en: "Enter a version or alias (node, stable, lts/*)",
        zh: "输入版本号 / alias(node, stable, lts/*)",
        command: "nvm use <version>",
        before: {
          en: "Version or alias (node, stable, lts/*)\n\n> 20",
          zh: "版本号或 alias(node, stable, lts/*)\n\n> 20",
        },
        body: `Now using node ${ver} (npm v10.8.2)`,
      },
      {
        en: "Use .nvmrc / .node-version in this directory",
        zh: "按当前目录 .nvmrc / .node-version",
        command: "nvm use",
        body: `Found '${home}/proj/.nvmrc' with version <20.11.0>\nNow using node ${ver} (npm v10.8.2)`,
      },
    ],
  },
  {
    en: "Show current",
    zh: "查看当前(current)",
    items: [
      { en: "Active version", zh: "当前激活版本", command: "nvm current", body: ver },
      {
        en: "Node path",
        zh: "node 路径",
        command: "nvm which current",
        body: `${root}/versions/node/${ver}/bin/node`,
      },
    ],
  },
  {
    en: "List versions (ls / ls-remote)",
    zh: "列出版本(ls / ls-remote)",
    items: [
      {
        en: "Installed",
        zh: "已安装",
        command: "nvm ls",
        body: `->     ${ver}\ndefault -> ${ver}`,
      },
      {
        en: "Remote, all",
        zh: "远程全部",
        command: "nvm ls-remote",
        body: "v22.23.4    (LTS: Jod)\nv24.22.1    (LTS: Krypton)\nv26.12.1",
      },
      {
        en: "Remote, LTS only",
        zh: "远程仅 LTS",
        command: "nvm ls-remote --lts",
        body: "v22.23.4    (LTS: Jod)\nv24.22.1    (LTS: Krypton)",
      },
    ],
  },
  {
    en: "Project",
    zh: "项目管理",
    items: [
      {
        en: "Read .nvmrc and use",
        zh: "读 .nvmrc 并 use",
        command: "nvm use",
        body: `Found '${home}/proj/.nvmrc' with version <20.11.0>\nNow using node ${ver} (npm v10.8.2)`,
      },
      {
        en: "Create .nvmrc with the current version if missing",
        zh: "没有则创建 .nvmrc(写当前版本)",
        command: "nvm use <current> --save",
        body: `Wrote version number (${ver}) to .nvmrc\nNow using node ${ver} (npm v10.8.2)`,
      },
      { en: "Install the .nvmrc version, then use", zh: "install 对齐 .nvmrc 再 use", command: "nvm install", body: installBody(ver) },
    ],
  },
  {
    en: "Aliases",
    zh: "别名(alias)",
    items: [
      { en: "Show aliases", zh: "查看别名", command: "nvm alias", body: `default -> ${ver}` },
      {
        en: "Set an alias",
        zh: "设置别名",
        command: "nvm alias <name> <target>",
        before: {
          en: "Alias name\n\n> stable\nTarget version or alias\n\n> 20.11.0",
          zh: "别名\n\n> stable\n目标版本或别名\n\n> 20.11.0",
        },
        body: `stable -> ${ver}`,
      },
      {
        en: "Delete an alias",
        zh: "删除别名",
        command: "nvm unalias <name>",
        before: { en: "Alias name to delete\n\n> stable", zh: "要删除的别名\n\n> stable" },
        body: "Deleted alias stable",
      },
    ],
  },
  {
    en: "Uninstall",
    zh: "卸载(uninstall)",
    items: [
      {
        en: "Choose an installed version",
        zh: "选已安装版本卸载",
        command: "nvm uninstall <version>",
        before: {
          en: `  1  ${ver}\n  0  Back\n\n> 1\n\nDelete ${ver}\n  1  Yes, uninstall\n  2  Cancel\n  0  Back\n\n> 1`,
          zh: `  1  ${ver}\n  0  返回\n\n> 1\n\n删除 ${ver}\n  1  确认删除\n  2  取消\n  0  返回\n\n> 1`,
        },
        body: `Uninstalled ${ver}`,
      },
    ],
  },
  {
    en: "Install",
    zh: "安装",
    items: [
      {
        en: "Install command",
        zh: "安装命令",
        command: null,
        body: "curl -fsSL https://znvm.dev/install.sh | bash",
      },
    ],
  },
  {
    en: "Registries (scopes)",
    zh: "镜像源(scope)",
    items: [
      {
        en: "View the current map",
        zh: "查看当前映射",
        command: "nvm registry show",
        body: "default https://registry.npmjs.org",
      },
      {
        en: "Add or edit a scope",
        zh: "添加或修改 scope",
        command: "nvm registry add <@scope> <url>",
        before: {
          en: "Scope (for example @company)\n\n> @company\nRegistry URL\n\n> https://npm.company.example",
          zh: "scope(例如 @company)\n\n> @company\n源地址\n\n> https://npm.company.example",
        },
        body: "default (not set)\n@company https://npm.company.example",
      },
      {
        en: "Delete a scope",
        zh: "删除 scope",
        command: "nvm registry remove <@scope>",
        before: {
          en: "Scope (for example @company)\n\n> @company",
          zh: "scope(例如 @company)\n\n> @company",
        },
        body: "default (not set)",
      },
      {
        en: "Set the default registry",
        zh: "设置默认源",
        command: "nvm registry set-default <url>",
        before: {
          en: "Default registry URL\n\n> https://registry.npmmirror.com",
          zh: "默认源地址\n\n> https://registry.npmmirror.com",
        },
        body: "default https://registry.npmmirror.com",
      },
      {
        en: "China default, keep scopes",
        zh: "中国默认源, 保留 scope",
        command: "nvm registry china",
        body: "default https://registry.npmmirror.com\n@company https://npm.company.example",
      },
      {
        en: "Sync npm, yarn, pnpm, and bun",
        zh: "同步 npm, yarn, pnpm, bun",
        command: "nvm registry sync",
        body: "default https://registry.npmmirror.com\n@company https://npm.company.example",
      },
      {
        en: "Restore the official registry",
        zh: "恢复官方源",
        command: "nvm registry official",
        body: "default https://registry.npmjs.org\n@company https://npm.company.example",
      },
    ],
  },
  {
    en: "Mirrors",
    zh: "下载镜像",
    items: [
      {
        en: "List",
        zh: "列出",
        command: "nvm mirror ls",
        body: "profile official\n  electron (unset)\n  playwright (unset)\n  node (unset)",
      },
      {
        en: "Use china",
        zh: "使用中国镜像",
        command: "nvm mirror use china",
        body: "The mirrors have been changed to 'china'.",
      },
      {
        en: "Use official",
        zh: "使用官方地址",
        command: "nvm mirror use official",
        body: "The mirrors have been changed to 'official'.",
      },
      {
        en: "Set one mirror",
        zh: "设置一个镜像",
        command: "nvm mirror set <name> <url>",
        body: "set electron",
      },
      {
        en: "Reset",
        zh: "还原",
        command: "nvm mirror reset",
        body: "mirrors reset",
      },
      {
        en: "Test",
        zh: "测速",
        command: "nvm mirror test",
        body: "electron china\nelectron official",
      },
      {
        en: "Use fastest",
        zh: "使用最快的一边",
        command: "nvm mirror use auto",
        body: "The mirrors have been changed to 'auto'.",
      },
    ],
  },
];

function transcript(zh: boolean, leaf: Leaf) {
  const pause = zh ? "回车继续" : "Press Enter to continue";
  const lines: string[] = [];
  if (leaf.before) {
    const preface = zh ? leaf.before.zh : leaf.before.en;
    if (preface) lines.push(preface);
  }
  if (leaf.command) lines.push(`${zh ? "正在执行:" : "Running:"} ${leaf.command}`);
  lines.push(zh && leaf.bodyZh ? leaf.bodyZh : leaf.body);
  lines.push("");
  lines.push(pause);
  return lines.join("\n");
}

export function GuideTerminal({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";
  const [group, setGroup] = useState<number | null>(null);
  const [result, setResult] = useState<Leaf | null>(null);
  const [closed, setClosed] = useState(false);
  const [typed, setTyped] = useState("");
  const [cursor, setCursor] = useState(0);
  const frame = useRef<HTMLDivElement>(null);

  const title = group === null
    ? `${zh ? "nvm" : "nvm"}${zh ? "(交互引导)" : " (interactive guide)"}`
    : zh ? menu[group].zh : menu[group].en;

  const items: { key: string; label: string; onPick: () => void }[] = result || closed
    ? []
    : group === null
      ? menu.map((entry, index) => ({
          key: entry.en,
          label: zh ? entry.zh : entry.en,
          onPick: () => {
            setCursor(0);
            setGroup(index);
          },
        }))
      : menu[group].items.map((entry) => ({
          key: entry.en,
          label: zh ? entry.zh : entry.en,
          onPick: () => {
            setCursor(0);
            setResult(entry);
          },
        }));

  function goBack() {
    setCursor(0);
    if (result) {
      setResult(null);
      return;
    }
    if (group !== null) {
      setGroup(null);
      return;
    }
    setClosed(true);
  }

  useEffect(() => {
    setTyped("");
    setCursor(0);
  }, [group, result, closed]);

  useEffect(() => {
    const node = frame.current;
    if (!node) return;
    function onKey(event: KeyboardEvent) {
      if (closed) return;
      if (result) {
        if (event.key === "Enter" || event.key === "0" || event.key === "Escape" || event.key === "q" || event.key === "ArrowLeft") {
          event.preventDefault();
          goBack();
        }
        return;
      }
      if (event.key === "ArrowUp" || event.key === "k") {
        event.preventDefault();
        setTyped("");
        setCursor((current) => (current === 0 ? items.length : current - 1));
        return;
      }
      if (event.key === "ArrowDown" || event.key === "j") {
        event.preventDefault();
        setTyped("");
        setCursor((current) => (current === items.length ? 0 : current + 1));
        return;
      }
      if (event.key === "ArrowLeft" || event.key === "Escape" || event.key === "q") {
        event.preventDefault();
        setTyped("");
        goBack();
        return;
      }
      if (typed === "1" && items.length > 9) {
        if (event.key === "0") {
          event.preventDefault();
          setTyped("");
          items[9]?.onPick();
          return;
        }
        if (event.key === "Enter") {
          event.preventDefault();
          setTyped("");
          items[0]?.onPick();
          return;
        }
        if (event.key === "Backspace") {
          event.preventDefault();
          setTyped("");
          return;
        }
      }
      if (event.key === "Enter") {
        event.preventDefault();
        if (cursor === items.length) goBack();
        else items[cursor]?.onPick();
        return;
      }
      if (event.key === "0") {
        event.preventDefault();
        goBack();
        return;
      }
      const choice = Number(event.key);
      if (!Number.isInteger(choice) || choice < 1 || choice > items.length) return;
      if (choice === 1 && items.length > 9) {
        event.preventDefault();
        setTyped("1");
        setCursor(0);
        return;
      }
      event.preventDefault();
      items[choice - 1]?.onPick();
    }
    node.addEventListener("keydown", onKey);
    return () => node.removeEventListener("keydown", onKey);
  }, [closed, cursor, group, items, result, typed, zh]);

  const backLabel = group === null ? (zh ? "退出" : "Exit") : zh ? "返回" : "Back";

  return (
    <section className="showcase">
      <div className="container py-12 md:py-16">
        <div>
          <h2 className="kicker">{zh ? "引导" : "Guide"}</h2>
          <p className="mt-3 max-w-[36rem] text-base leading-relaxed text-muted-foreground">
            {zh ? "不用记子命令。" : "Open it and pick."}
          </p>
          <div
            ref={frame}
            className="term-frame term-frame-fixed mt-8 bg-[#12110f] outline-none focus-visible:ring-2 focus-visible:ring-node"
            data-ui="terminal"
            tabIndex={0}
            role="group"
            aria-label={zh ? "NVM 交互引导" : "NVM interactive guide"}
          >
            <div className="term-chrome">
              <span className="term-dot" />
              <span className="term-dot" />
              <span className="term-dot" />
              <span className="term-title">nvm</span>
            </div>
            <pre className="term-body">
              {result ? (
                <button type="button" className="term-key block whitespace-pre-wrap text-left" onClick={() => setResult(null)}>
                  {transcript(zh, result)}
                </button>
              ) : closed ? (
                <span className="term-prompt">&gt; </span>
              ) : (
                <>
                  <span className="term-menu-title">{title}</span>
                  {"\n\n"}
                  {items.map((item, index) => (
                    <button
                      key={item.key}
                      type="button"
                      className={cursor === index ? "term-choice term-choice-active" : "term-choice"}
                      onClick={item.onPick}
                    >
                      {`${cursor === index ? "> " : "  "}${String(index + 1).padStart(items.length >= 10 ? 2 : 1, " ")}  ${item.label}\n`}
                    </button>
                  ))}
                  <button
                    type="button"
                    className={cursor === items.length ? "term-choice term-choice-active" : "term-choice"}
                    onClick={goBack}
                  >
                    {`${cursor === items.length ? "> " : "  "}${String(0).padStart(items.length >= 10 ? 2 : 1, " ")}  ${backLabel}\n`}
                  </button>
                  {typed ? <span className="term-prompt">{`\n${typed}`}</span> : null}
                </>
              )}
            </pre>
          </div>
          {closed ? (
            <button
              type="button"
              className="mt-4 text-sm text-node-bright"
              onClick={() => {
                setClosed(false);
                setGroup(null);
                setResult(null);
              }}
            >
              {zh ? "重新打开" : "Open the guide again"}
            </button>
          ) : null}
        </div>
      </div>
    </section>
  );
}
