"use client";

import { useEffect, useRef, useState } from "react";

type Leaf = { en: string; zh: string; command: string; result: string };
type Group = { en: string; zh: string; items: Leaf[] };

const menu: Group[] = [
  {
    en: "Install Node",
    zh: "安装 Node",
    items: [
      { en: "Install latest LTS", zh: "装最新 LTS", command: "nvm install --lts", result: "Installed the latest LTS." },
      { en: "Install latest Current", zh: "装最新 Current", command: "nvm install node", result: "Installed the latest Current." },
      { en: "Enter a version (20.18.0 / lts/hydrogen)", zh: "输入具体版本（如 20.18.0 / lts/hydrogen）", command: "nvm install <version>", result: "Asks for a version, then installs it." },
      { en: "Pick from the remote list, then install", zh: "从远程列表里选一个再装", command: "nvm ls-remote", result: "Shows the remote list, 15 versions per page, then installs the one you pick." },
    ],
  },
  {
    en: "Switch version (use)",
    zh: "切换版本（use）",
    items: [
      { en: "Choose an installed version", zh: "选已安装版本", command: "nvm use <version>", result: "Lists installed versions. The one you pick becomes current." },
      { en: "Enter a version or alias (node, stable, lts/*)", zh: "输入版本号 / alias（node、stable、lts/*）", command: "nvm use <version>", result: "Resolves the version or alias, then switches." },
      { en: "Use .nvmrc / .node-version in this directory", zh: "按当前目录 .nvmrc / .node-version", command: "nvm use", result: "Reads .nvmrc, or .node-version when no .nvmrc exists." },
    ],
  },
  {
    en: "Show current",
    zh: "查看当前（current）",
    items: [
      { en: "Active version", zh: "当前激活版本", command: "nvm current", result: "Prints the active version, or none." },
      { en: "Path under NVM_DIR", zh: "对应路径（NVM_DIR 下）", command: "nvm which current", result: "Prints the node binary under $NVM_DIR/versions/node." },
    ],
  },
  {
    en: "List versions (ls / ls-remote)",
    zh: "列出版本（ls / ls-remote）",
    items: [
      { en: "Installed", zh: "已安装", command: "nvm ls", result: "Lists versions in $NVM_DIR/versions/node." },
      { en: "Remote, all", zh: "远程全部", command: "nvm ls-remote", result: "Lists installable releases from the mirror." },
      { en: "Remote, LTS only", zh: "远程仅 LTS", command: "nvm ls-remote --lts", result: "Lists LTS releases only." },
    ],
  },
  {
    en: "Project",
    zh: "项目管理",
    items: [
      { en: "Read .nvmrc and use", zh: "读 .nvmrc 并 use", command: "nvm use", result: "Switches to the version in .nvmrc." },
      { en: "Create .nvmrc with the current version if missing", zh: "没有则创建 .nvmrc（写当前版本）", command: "nvm use <current> --save", result: "If .nvmrc is missing, writes the active version. An existing file is left as it is." },
      { en: "Install the .nvmrc version, then use", zh: "install 对齐 .nvmrc 再 use", command: "nvm install", result: "Installs the version from .nvmrc, then switches to it." },
    ],
  },
  {
    en: "Aliases",
    zh: "别名（alias）",
    items: [
      { en: "Show aliases", zh: "查看别名", command: "nvm alias", result: "Prints alias names and targets." },
      { en: "Set an alias", zh: "设置别名", command: "nvm alias <name> <target>", result: "Asks for a name and a target, then saves the alias." },
      { en: "Delete an alias", zh: "删除别名", command: "nvm unalias <name>", result: "Asks for a name, then deletes that alias." },
    ],
  },
  {
    en: "Uninstall",
    zh: "卸载（uninstall）",
    items: [
      { en: "Choose an installed version", zh: "选已安装版本卸载", command: "nvm uninstall <version>", result: "Pick a version, then confirm before it is deleted." },
      { en: "Confirm, then delete", zh: "确认后再删", command: "nvm uninstall <version>", result: "The same check: choose a version, then confirm." },
    ],
  },
  {
    en: "Install / migrate (install-as-nvm)",
    zh: "安装 / 迁移（install-as-nvm）",
    items: [
      { en: "Print the install-as-nvm.sh curl (does not run it)", zh: "指向官网 install-as-nvm.sh（打印 curl，不替用户 curl）", command: "curl -fsSL https://znvm.dev/install-as-nvm.sh | bash", result: "Prints the command. It does not run curl for you." },
      { en: "Shell hooks (bashrc / zshrc / fish)", zh: "说明 shell 钩子（bashrc / zshrc / fish）", command: "export NVM_DIR=\"$HOME/.nvm\"", result: "bash and zsh source nvm.sh. fish is not given that file to source." },
      { en: "Default npmmirror / NVM_NODEJS_ORG_MIRROR", zh: "说明默认 npmmirror / NVM_NODEJS_ORG_MIRROR", command: "NVM_NODEJS_ORG_MIRROR", result: "Downloads use https://npmmirror.com/mirrors/node unless that variable is set." },
    ],
  },
  {
    en: "Registries (scopes)",
    zh: "镜像源（scope）",
    items: [
      { en: "View the current map", zh: "查看当前映射", command: "nvm registry show", result: "Prints the default registry and every @scope route." },
      { en: "Add or edit a scope", zh: "添加或修改 scope", command: "nvm registry add <@scope> <url>", result: "Saves that scope and syncs npm, yarn, pnpm, and bun." },
      { en: "Delete a scope", zh: "删除 scope", command: "nvm registry remove <@scope>", result: "Removes that scope and syncs the package managers." },
      { en: "Set the default registry", zh: "设置默认源", command: "nvm registry set-default <url>", result: "Sets the default URL and leaves the other scopes in place." },
      { en: "China default, keep scopes", zh: "中国默认源，保留 scope", command: "nvm registry china", result: "Default becomes https://registry.npmmirror.com. Scope routes stay." },
      { en: "Sync npm, yarn, pnpm, and bun", zh: "同步 npm、yarn、pnpm、bun", command: "nvm registry sync", result: "Rewrites ~/.npmrc, ~/.yarnrc, ~/.yarnrc.yml, the pnpm rc, and ~/.bunfig.toml." },
      { en: "Restore the official registry", zh: "恢复官方源", command: "nvm registry official", result: "Default becomes https://registry.npmjs.org. Scope routes stay." },
    ],
  },
];

export function GuideTerminal({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";
  const [group, setGroup] = useState<number | null>(null);
  const [result, setResult] = useState<Leaf | null>(null);
  const [closed, setClosed] = useState(false);
  const frame = useRef<HTMLDivElement>(null);

  const title = closed
    ? zh ? "已退出" : "Exited"
    : result
      ? zh ? "正在执行" : "Running"
      : group === null
        ? zh ? "nvm（交互引导）" : "nvm (interactive guide)"
        : zh ? menu[group].zh : menu[group].en;

  const items: { key: string; label: string; onPick: () => void }[] = closed
    ? []
    : result
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

  return (
    <section className="py-16 sm:py-20">
      <div className="container">
        <div className="mx-auto max-w-3xl">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            {zh ? "交互引导" : "Interactive guide"}
          </h2>
          <p className="mt-4 text-muted-foreground">
            {zh
              ? "在终端里不带参数运行 nvm 会打开这个菜单。下面是同一棵两级菜单，可以点数字走一遍。0 返回，在根菜单则退出。"
              : "Running nvm with no arguments opens this menu. The same two-level tree is below. Pick a number. 0 goes back, and on the root menu it exits."}
          </p>
          <div
            ref={frame}
            className="term-frame mt-8 outline-none focus-visible:ring-2 focus-visible:ring-orange-500"
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
            <div className="term-body">
              <p className="term-menu-title">{title}</p>
              {result ? (
                <div className="mt-4 space-y-2">
                  <p>
                    <span className="term-prompt">$ </span>
                    {result.command}
                  </p>
                  <p className="term-out">{zh ? resultLabel(result) : result.result}</p>
                  <button type="button" className="term-key" onClick={() => setResult(null)}>
                    {zh ? "回车继续" : "Press Enter to continue"}
                  </button>
                </div>
              ) : null}
              {closed ? (
                <button
                  type="button"
                  className="term-key mt-4"
                  onClick={() => {
                    setClosed(false);
                    setGroup(null);
                    setResult(null);
                  }}
                >
                  {zh ? "重新打开" : "Open the guide again"}
                </button>
              ) : null}
              <ul className="mt-4 space-y-1">
                {items.map((item, index) => (
                  <li key={item.key}>
                    <button type="button" className="term-choice" onClick={item.onPick}>
                      <span className="term-num">{index + 1}</span>
                      {item.label}
                    </button>
                  </li>
                ))}
                {items.length > 0 ? (
                  <li>
                    <button type="button" className="term-choice" onClick={goBack}>
                      <span className="term-num">0</span>
                      {group === null ? (zh ? "退出" : "Exit") : zh ? "返回" : "Back"}
                    </button>
                  </li>
                ) : null}
              </ul>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function resultLabel(leaf: Leaf): string {
  const zhResults: Record<string, string> = {
    "nvm install --lts": "安装最新 LTS。",
    "nvm install node": "安装最新 Current。",
    "nvm install <version>": "询问版本号，然后安装。",
    "nvm ls-remote": "先给出远程列表，每页 15 个，再安装选中的版本。",
    "nvm use <version>": "解析版本或别名，然后切换。",
    "nvm use": "读取 .nvmrc；没有 .nvmrc 时才读 .node-version。",
    "nvm current": "打印当前版本；没有则是 none。",
    "nvm which current": "打印 $NVM_DIR/versions/node 下的 node 路径。",
    "nvm ls": "列出 $NVM_DIR/versions/node 里的版本。",
    "nvm ls-remote --lts": "只列出 LTS。",
    "nvm use <current> --save": "没有 .nvmrc 时写入当前版本。已有文件不会被覆盖。",
    "nvm install": "按 .nvmrc 安装，然后切换过去。",
    "nvm alias": "打印别名和目标。",
    "nvm alias <name> <target>": "询问别名和目标，然后保存。",
    "nvm unalias <name>": "询问别名，然后删除。",
    "nvm uninstall <version>": "先选版本，确认后才删除。",
    "curl -fsSL https://znvm.dev/install-as-nvm.sh | bash": "只打印这条命令，不会替你执行 curl。",
    "export NVM_DIR=\"$HOME/.nvm\"": "bash 和 zsh 会 source nvm.sh。fish 不能 source 这个文件。",
    "NVM_NODEJS_ORG_MIRROR": "默认从 https://npmmirror.com/mirrors/node 下载，除非设置了这个变量。",
    "nvm registry show": "打印默认源和每一个 @scope 路由。",
    "nvm registry add <@scope> <url>": "保存这个 scope，并同步 npm、yarn、pnpm、bun。",
    "nvm registry remove <@scope>": "删除这个 scope，并同步各包管理器。",
    "nvm registry set-default <url>": "设置默认源，其他 scope 保留。",
    "nvm registry china": "默认源改为 https://registry.npmmirror.com，scope 保留。",
    "nvm registry sync": "改写 ~/.npmrc、~/.yarnrc、~/.yarnrc.yml、pnpm rc 和 ~/.bunfig.toml。",
    "nvm registry official": "默认源改为 https://registry.npmjs.org，scope 保留。",
  };
  if (leaf.command === "nvm use <version>" && leaf.en.startsWith("Choose")) {
    return "列出已安装版本，选中的成为当前版本。";
  }
  if (leaf.command === "nvm uninstall <version>" && leaf.en.startsWith("Confirm")) {
    return "同样是先选版本，确认后才删除。";
  }
  return zhResults[leaf.command] ?? leaf.result;
}
