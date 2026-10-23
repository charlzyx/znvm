"use client";

const rows = {
  en: [
    ["Install, use, and list Node", "yes", "no", "yes"],
    ["Drop-in NVM_DIR=~/.nvm and nvm commands", "yes", "no", "yes"],
    ["Default Node download host", "nodejs.org", "no", "npmmirror"],
    ["Interactive guide", "no", "no", "yes"],
    ["Several @scope registries", "no", "no", "yes"],
    ["Writes npm, yarn, pnpm, and bun", "no", "npm", "yes"],
    ["Electron and other binary mirrors", "no", "optional in nrm", "yes, nvm mirror"],
  ],
  zh: [
    ["安装、切换、列出 Node", "有", "无", "有"],
    ["兼容 NVM_DIR=~/.nvm 和 nvm 命令", "有", "无", "有"],
    ["默认 Node 下载站", "nodejs.org", "无", "npmmirror"],
    ["交互引导", "无", "无", "有"],
    ["多个 @scope 源", "无", "无", "有"],
    ["写入 npm、yarn、pnpm、bun", "无", "npm", "有"],
    ["Electron 等二进制镜像", "无", "nrm 可选", "有, nvm mirror"],
  ],
} as const;

export function Compare({ lang = "en" }: { lang?: "en" | "zh" }) {
  const zh = lang === "zh";
  const body = zh ? rows.zh : rows.en;
  const headers = zh ? ["", "nvm", "nrm", "znvm"] : ["", "nvm", "nrm", "znvm"];

  return (
    <section className="border-b border-border py-12 sm:py-16">
      <div className="container">
        <div>
            <h2 className="text-3xl font-semibold tracking-[-0.03em] sm:text-4xl">
            {zh ? "对比" : "Compare"}
          </h2>
          <p className="mt-4 max-w-[65ch] text-base leading-relaxed text-foreground">
            {zh
              ? "一次安装有 nvm 和 nrm。nrm 列是原来的源工具。下载镜像是 nvm mirror。"
              : "One install provides nvm and nrm. The nrm column is the original registry tool. Download hosts are nvm mirror."}
          </p>
          <div className="mt-10 border border-border md:hidden">
            {body.map((row) => (
              <article key={row[0]} className="border-b border-border p-5 last:border-b-0">
                <h3 className="text-lg font-semibold">{row[0]}</h3>
                <dl className="mt-3 grid grid-cols-[5rem_1fr] gap-y-1 text-base">
                  <dt>nvm</dt>
                  <dd className="text-muted-foreground">{row[1]}</dd>
                  <dt>nrm</dt>
                  <dd className="text-muted-foreground">{row[2]}</dd>
                  <dt className="font-medium text-node-bright">znvm</dt>
                  <dd className="font-medium text-node-bright">{row[3]}</dd>
                </dl>
              </article>
            ))}
          </div>
          <div className="mt-10 hidden min-w-0 overflow-x-auto border border-border md:block">
            <table className="w-full min-w-[40rem] text-left text-base">
              <thead className="bg-muted text-sm font-semibold text-foreground">
                <tr>
                  {headers.map((header) => (
                    <th key={header || "capability"} scope="col" className="px-5 py-4 font-medium">
                      {header}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {body.map((row) => (
                  <tr key={row[0]} className="border-t border-border">
                    <th scope="row" className="px-5 py-4 font-normal text-foreground">
                      {row[0]}
                    </th>
                    <td className="px-5 py-4 text-muted-foreground">{row[1]}</td>
                    <td className="px-5 py-4 text-muted-foreground">{row[2]}</td>
                    <td className="px-5 py-4 font-medium text-node-bright">{row[3]}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </section>
  );
}
