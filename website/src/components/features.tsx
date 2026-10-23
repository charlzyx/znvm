"use client";

const features = {
  en: [
    {
      title: "Drop-in nvm",
      body: "install-as-nvm.sh installs the nvm command and links nrm to the same binary. Versions live in ~/.nvm ($NVM_DIR). The shell hook exports NVM_DIR, sources nvm.sh, and puts that directory first on PATH. Everyday commands are install, use, ls, current, alias, and uninstall.",
    },
    {
      title: "npmmirror by default",
      body: "Node archives download from https://npmmirror.com/mirrors/node. Set NVM_NODEJS_ORG_MIRROR when you want a different mirror.",
    },
    {
      title: "Interactive guide",
      body: "In a terminal, nvm with no arguments opens a number menu. nvm guide and nvm interactive open the same menu. Chinese prompts follow a locale that starts with zh. Without a terminal it prints a short notice and exits.",
    },
    {
      title: "Scope registries",
      body: "nrm ls, nrm use, nrm current, nrm add, nrm del, and nrm test use the usual registry names. nrm scope add @company <url> keeps several scope routes. nrm use auto writes the fastest registry that answers. nvm registry is the same map. In a terminal, nrm with no arguments opens a menu for registries, scopes, and tests. Sync writes ~/.npmrc, ~/.yarnrc, ~/.yarnrc.yml, the pnpm rc, and ~/.bunfig.toml.",
    },
    {
      title: "Download mirrors",
      body: "nvm mirror use china writes the Node dist host and the download hosts for Electron, Playwright, Cypress, puppeteer, sharp, node-sass, and the other common tools. official clears them. nvm mirror test measures in parallel. nvm mirror use auto keeps the faster side of each tool. Scope routes stay put. Nothing runs on install. The nvm guide lists this as Mirrors.",
    },
    {
      title: "For agents",
      body: "nvm --llm prints the usage guide. nrm --llm prints the same text. --json prints one object for versions, registries, and mirrors. Menus stay closed when CI is set, or with --yes or NVM_NONINTERACTIVE=1. There is no MCP server.",
    },
  ],
  zh: [
    {
      title: "当作 nvm 使用",
      body: "install-as-nvm.sh 安装 nvm，并把 nrm 链接到同一个二进制。版本在 ~/.nvm（$NVM_DIR）。shell 钩子导出 NVM_DIR、source nvm.sh，并把该目录放到 PATH 最前。日常命令是 install、use、ls、current、alias 和 uninstall。",
    },
    {
      title: "默认 npmmirror",
      body: "Node 压缩包从 https://npmmirror.com/mirrors/node 下载。要换镜像，设置 NVM_NODEJS_ORG_MIRROR。",
    },
    {
      title: "交互引导",
      body: "在终端里不带参数运行 nvm 会打开数字菜单。nvm guide 和 nvm interactive 是同一个菜单。语言以 zh 开头时用中文。没有终端时只打印一句说明并退出。",
    },
    {
      title: "按 scope 分流源",
      body: "nrm ls、nrm use、nrm current、nrm add、nrm del 和 nrm test 使用常见的源名字。nrm scope add @company <url> 保存多条 scope。nrm use auto 写入最快且有响应的源。nvm registry 改的是同一张表。在终端里不带参数运行 nrm 会打开菜单，里面有源、scope 和测速。同步会写入 ~/.npmrc、~/.yarnrc、~/.yarnrc.yml、pnpm 的 rc 和 ~/.bunfig.toml。",
    },
    {
      title: "下载镜像",
      body: "nvm mirror use china 写入 Node 发行包地址，以及 Electron、Playwright、Cypress、puppeteer、sharp、node-sass 和其他常见工具的下载地址。official 会清掉它们。nvm mirror test 并行测量。nvm mirror use auto 为每个工具留下更快的一边。scope 保持不动。安装时不会测量。nvm 的引导菜单里这一项是「下载镜像」。",
    },
    {
      title: "给 Agent",
      body: "nvm --llm 打印用法说明。nrm --llm 打印同一段文字。--json 为版本、源和下载镜像各打一个 JSON 对象。CI 已设置，或者带上 --yes 或 NVM_NONINTERACTIVE=1 时，菜单不会打开。没有 MCP 服务。",
    },
  ],
};

export function Features({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";
  const items = zh ? features.zh : features.en;

  return (
    <section className="py-16 sm:py-20">
      <div className="container">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
          {zh ? "它现在能做什么" : "What it does"}
        </h2>
        <div className="mt-8 grid gap-4 md:grid-cols-2">
          {items.map((item) => (
            <article key={item.title} className="rounded-xl border border-white/10 bg-white/[0.03] p-6">
              <h3 className="text-sm font-semibold text-node-bright">{item.title}</h3>
              <p className="mt-3 text-sm leading-6 text-muted-foreground">{item.body}</p>
            </article>
          ))}
        </div>
        <p className="mt-6 max-w-3xl text-sm text-muted-foreground">
          {zh
            ? "Docker 镜像不在这里设置。把 Docker daemon 指到镜像需要改特权配置并重启 daemon。"
            : "Docker image mirrors are not set here. Pointing the Docker daemon at a mirror needs a privileged config and a daemon restart."}
        </p>
      </div>
    </section>
  );
}
