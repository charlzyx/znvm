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
const wrote = [
  `Wrote ${home}/.npmrc`,
  `Wrote ${home}/.yarnrc`,
  `Wrote ${home}/.yarnrc.yml`,
  `Wrote ${home}/.config/pnpm/rc`,
  `Wrote ${home}/.bunfig.toml`,
].join("\n");

function installBody(version: string) {
  return [
    `Installing ${version} (x64)...`,
    "Extracting...",
    `Installed ${version}`,
    `default -> ${version}`,
    `Using ${version}`,
  ].join("\n");
}

const hooksEn = `bash uses ~/.bashrc. zsh uses ~/.zshrc:

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

The installer does not edit fish config. nvm.sh is a bash/zsh file, so fish cannot source it.
You can still set the data directory in fish:

set -gx NVM_DIR $HOME/.nvm

Switch versions from the nvm function in bash or zsh.`;

const hooksZh = `bash 写在 ~/.bashrc, zsh 写在 ~/.zshrc:

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

fish 不会被安装脚本修改. nvm.sh 是 bash/zsh 文件, fish 不能 source 它.
在 fish 里可以设置数据目录:

set -gx NVM_DIR $HOME/.nvm

切换版本仍使用 bash 或 zsh 里的 nvm 函数.`;

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
        body: `Using ${ver}`,
      },
      {
        en: "Enter a version or alias (node, stable, lts/*)",
        zh: "输入版本号 / alias(node, stable, lts/*)",
        command: "nvm use <version>",
        before: {
          en: "Version or alias (node, stable, lts/*)\n\n> 20",
          zh: "版本号或 alias(node, stable, lts/*)\n\n> 20",
        },
        body: `Using ${ver}`,
      },
      {
        en: "Use .nvmrc / .node-version in this directory",
        zh: "按当前目录 .nvmrc / .node-version",
        command: "nvm use",
        body: `Found '${home}/proj/.nvmrc' with version <20.11.0>\nUsing ${ver}`,
      },
    ],
  },
  {
    en: "Show current",
    zh: "查看当前(current)",
    items: [
      { en: "Active version", zh: "当前激活版本", command: "nvm current", body: ver },
      {
        en: "Path under NVM_DIR",
        zh: "对应路径(NVM_DIR 下)",
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
        body: `Found '${home}/proj/.nvmrc' with version <20.11.0>\nUsing ${ver}`,
      },
      {
        en: "Create .nvmrc with the current version if missing",
        zh: "没有则创建 .nvmrc(写当前版本)",
        command: "nvm use <current> --save",
        body: `Wrote version number (${ver}) to .nvmrc\nUsing ${ver}`,
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
      {
        en: "Confirm, then delete",
        zh: "确认后再删",
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
    en: "Install / migrate (install-as-nvm)",
    zh: "安装 / 迁移(install-as-nvm)",
    items: [
      {
        en: "Print the install-as-nvm.sh curl (does not run it)",
        zh: "指向官网 install-as-nvm.sh(打印 curl, 不替用户 curl)",
        command: null,
        body: "curl -fsSL https://znvm.dev/install-as-nvm.sh | bash\n\nAfter it finishes, the command is nvm and versions live in ~/.nvm.",
        bodyZh: "curl -fsSL https://znvm.dev/install-as-nvm.sh | bash\n\n结束后命令是 nvm, 版本在 ~/.nvm.",
        before: {
          en: "Install command (not run from this menu):\n",
          zh: "安装命令(这个菜单不会替你执行):\n",
        },
      },
      {
        en: "Shell hooks (bashrc / zshrc / fish)",
        zh: "说明 shell 钩子(bashrc / zshrc / fish)",
        command: null,
        body: hooksEn,
        bodyZh: hooksZh,
      },
      {
        en: "Default npmmirror / NVM_NODEJS_ORG_MIRROR",
        zh: "说明默认 npmmirror / NVM_NODEJS_ORG_MIRROR",
        command: null,
        body: "The default download mirror is https://npmmirror.com/mirrors/node.\nSet NVM_NODEJS_ORG_MIRROR to use a different mirror.\nActive mirror: https://npmmirror.com/mirrors/node",
        bodyZh: "默认下载镜像是 https://npmmirror.com/mirrors/node.\n设置 NVM_NODEJS_ORG_MIRROR 可以换成别的镜像.\n当前镜像: https://npmmirror.com/mirrors/node",
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
        body: `No registry map in ${root}/registries.json\nSync writes:\n  ${home}/.npmrc\n  ${home}/.yarnrc\n  ${home}/.yarnrc.yml\n  ${home}/.config/pnpm/rc\n  ${home}/.bunfig.toml`,
      },
      {
        en: "Add or edit a scope",
        zh: "添加或修改 scope",
        command: "nvm registry add <@scope> <url>",
        before: {
          en: "Scope (for example @company)\n\n> @company\nRegistry URL\n\n> https://npm.company.example",
          zh: "scope(例如 @company)\n\n> @company\n源地址\n\n> https://npm.company.example",
        },
        body: `default (not set)\n@company https://npm.company.example\n${wrote}`,
      },
      {
        en: "Delete a scope",
        zh: "删除 scope",
        command: "nvm registry remove <@scope>",
        before: {
          en: "Scope (for example @company)\n\n> @company",
          zh: "scope(例如 @company)\n\n> @company",
        },
        body: `default (not set)\n${wrote}`,
      },
      {
        en: "Set the default registry",
        zh: "设置默认源",
        command: "nvm registry set-default <url>",
        before: {
          en: "Default registry URL\n\n> https://registry.npmmirror.com",
          zh: "默认源地址\n\n> https://registry.npmmirror.com",
        },
        body: `default https://registry.npmmirror.com\n${wrote}`,
      },
      {
        en: "China default, keep scopes",
        zh: "中国默认源, 保留 scope",
        command: "nvm registry china",
        body: `default https://registry.npmmirror.com\n@company https://npm.company.example\n${wrote}`,
      },
      {
        en: "Sync npm, yarn, pnpm, and bun",
        zh: "同步 npm, yarn, pnpm, bun",
        command: "nvm registry sync",
        body: `default https://registry.npmmirror.com\n@company https://npm.company.example\n${wrote}`,
      },
      {
        en: "Restore the official registry",
        zh: "恢复官方源",
        command: "nvm registry official",
        body: `default https://registry.npmjs.org\n@company https://npm.company.example\n${wrote}`,
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
          onPick: () => setGroup(index),
        }))
      : menu[group].items.map((entry) => ({
          key: entry.en,
          label: zh ? entry.zh : entry.en,
          onPick: () => setResult(entry),
        }));

  function goBack() {
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
    const node = frame.current;
    if (!node) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "0" || (event.key === "Enter" && result)) {
        event.preventDefault();
        goBack();
        return;
      }
      const choice = Number(event.key);
      if (!Number.isInteger(choice) || choice < 1 || choice > items.length) return;
      event.preventDefault();
      items[choice - 1]?.onPick();
    }
    node.addEventListener("keydown", onKey);
    return () => node.removeEventListener("keydown", onKey);
  }, [closed, group, items, result, zh]);

  const backLabel = group === null ? (zh ? "退出" : "Exit") : zh ? "返回" : "Back";

  return (
    <section className="py-16 sm:py-20">
      <div className="container">
        <div className="mx-auto max-w-3xl">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            {zh ? "交互引导" : "Interactive guide"}
          </h2>
          <p className="mt-4 text-muted-foreground">
            {zh
              ? "在终端里不带参数运行 nvm 会打开这个菜单. 下面是同一棵两级菜单, 可以点数字走一遍. 0 返回, 在根菜单则退出."
              : "Running nvm with no arguments opens this menu. The same two-level tree is below. Pick a number. 0 goes back, and on the root menu it exits."}
          </p>
          <div
            ref={frame}
            className="term-frame mt-8 outline-none focus-visible:ring-2 focus-visible:ring-node"
            tabIndex={0}
            role="group"
            aria-label={zh ? "nvm 交互引导演示" : "nvm interactive guide demo"}
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
                    <button key={item.key} type="button" className="term-choice" onClick={item.onPick}>
                      {`  ${index + 1}  ${item.label}\n`}
                    </button>
                  ))}
                  <button type="button" className="term-choice" onClick={goBack}>
                    {`  0  ${backLabel}\n`}
                  </button>
                  {"\n"}
                  <span className="term-prompt">&gt; </span>
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
