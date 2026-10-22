"use client";

const features = {
  en: [
    {
      title: "Drop-in nvm",
      body: "install-as-nvm.sh installs the nvm command. Versions live in ~/.nvm ($NVM_DIR). The shell hook exports NVM_DIR and sources nvm.sh. Everyday commands are install, use, ls, current, alias, and uninstall.",
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
      body: "Keep a default registry and any number of @scope routes, for example @company to an intranet registry and everything else on npmmirror. nvm registry china and nvm registry official change only the default. Sync writes ~/.npmrc, ~/.yarnrc, ~/.yarnrc.yml, the pnpm rc, and ~/.bunfig.toml.",
    },
  ],
  zh: [
    {
      title: "当作 nvm 使用",
      body: "install-as-nvm.sh 安装的命令是 nvm。版本在 ~/.nvm（$NVM_DIR）。shell 钩子导出 NVM_DIR 并 source nvm.sh。日常命令是 install、use、ls、current、alias 和 uninstall。",
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
      body: "可以同时保存一个默认源和任意多个 @scope，例如 @company 走内网，其余走 npmmirror。nvm registry china 和 nvm registry official 只改默认源。同步会写入 ~/.npmrc、~/.yarnrc、~/.yarnrc.yml、pnpm 的 rc 和 ~/.bunfig.toml。",
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
              <h3 className="font-mono text-sm text-orange-300">{item.title}</h3>
              <p className="mt-3 text-sm leading-6 text-muted-foreground">{item.body}</p>
            </article>
          ))}
        </div>
        <p className="mt-6 max-w-3xl text-sm text-muted-foreground">
          {zh
            ? "Electron 和其他二进制镜像还没有接入。registry 只处理包的源。"
            : "Electron and other binary mirrors are not wired up. registry only writes package registries."}
        </p>
      </div>
    </section>
  );
}
