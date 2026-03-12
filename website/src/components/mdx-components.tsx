import { ReactNode, ImgHTMLAttributes, AnchorHTMLAttributes } from "react"

interface ComponentProps {
  children?: ReactNode;
}

interface CodeProps extends ComponentProps {
  className?: string;
}

interface LinkProps extends AnchorHTMLAttributes<HTMLAnchorElement> {
  children?: ReactNode;
}

interface ImageProps extends ImgHTMLAttributes<HTMLImageElement> {
  src?: string;
  alt?: string;
}

export const MdxComponents = {
  // Text elements
  p: ({ children }: ComponentProps) => (
    <p className="mb-4 leading-7 [&:not(:first-child)]:mt-6">
      {children}
    </p>
  ),

  // Headings
  h1: ({ children }: ComponentProps) => (
    <h1 className="mt-2 scroll-m-20 text-4xl font-bold tracking-tight">
      {children}
    </h1>
  ),
  h2: ({ children }: ComponentProps) => (
    <h2 className="mt-12 scroll-m-20 border-b pb-1 text-2xl font-semibold tracking-tight first:mt-0">
      {children}
    </h2>
  ),
  h3: ({ children }: ComponentProps) => (
    <h3 className="mt-8 scroll-m-20 text-xl font-semibold tracking-tight">
      {children}
    </h3>
  ),
  h4: ({ children }: ComponentProps) => (
    <h4 className="mt-8 scroll-m-20 text-lg font-semibold tracking-tight">
      {children}
    </h4>
  ),
  h5: ({ children }: ComponentProps) => (
    <h5 className="mt-8 scroll-m-20 text-base font-semibold tracking-tight">
      {children}
    </h5>
  ),
  h6: ({ children }: ComponentProps) => (
    <h6 className="mt-8 scroll-m-20 text-sm font-semibold tracking-tight">
      {children}
    </h6>
  ),

  // Lists
  ul: ({ children }: ComponentProps) => (
    <ul className="my-6 ml-6 list-disc [&>li]:mt-2">
      {children}
    </ul>
  ),
  ol: ({ children }: ComponentProps) => (
    <ol className="my-6 ml-6 list-decimal [&>li]:mt-2">
      {children}
    </ol>
  ),
  li: ({ children }: ComponentProps) => (
    <li className="mt-2">
      {children}
    </li>
  ),

  // 行内代码
  code: ({ children, className }: CodeProps) => (
    <code className={`relative rounded bg-slate-200 px-[0.3rem] py-[0.2rem] font-mono text-sm font-semibold text-slate-900 dark:bg-slate-800 dark:text-slate-100 ${className || ""}`}>
      {children}
    </code>
  ),
  pre: ({ children }: ComponentProps) => (
    <pre className="mb-4 mt-6 overflow-x-auto rounded-lg border bg-slate-100 p-4 text-slate-900 dark:bg-slate-900 dark:text-slate-50">
      {children}
    </pre>
  ),

  // Links
  a: ({ children, href, ...props }: LinkProps) => (
    <a href={href} className="font-medium underline underline-offset-4 hover:text-primary" {...props}>
      {children}
    </a>
  ),

  // Blockquote
  blockquote: ({ children }: ComponentProps) => (
    <blockquote className="mt-6 border-l-2 border-primary pl-6 italic text-muted-foreground">
      {children}
    </blockquote>
  ),

  // Horizontal rule
  hr: () => (
    <hr className="my-4 md:my-8" />
  ),

  // Table
  table: ({ children }: ComponentProps) => (
    <div className="my-6 w-full overflow-y-auto">
      <table className="w-full border-collapse">
        {children}
      </table>
    </div>
  ),
  thead: ({ children }: ComponentProps) => (
    <thead className="border-b bg-muted/50">
      {children}
    </thead>
  ),
  tbody: ({ children }: ComponentProps) => (
    <tbody>
      {children}
    </tbody>
  ),
  tr: ({ children }: ComponentProps) => (
    <tr className="border-b hover:bg-muted/50">
      {children}
    </tr>
  ),
  th: ({ children }: ComponentProps) => (
    <th className="px-4 py-2 text-left font-semibold">
      {children}
    </th>
  ),
  td: ({ children }: ComponentProps) => (
    <td className="px-4 py-2">
      {children}
    </td>
  ),

  // Images
  img: ({ src, alt }: ImageProps) => (
    <img
      src={src}
      alt={alt}
      className="my-6 max-w-full rounded-lg border"
    />
  ),

  // Strong and emphasis
  strong: ({ children }: ComponentProps) => (
    <strong className="font-semibold">
      {children}
    </strong>
  ),
  em: ({ children }: ComponentProps) => (
    <em className="italic">
      {children}
    </em>
  ),
}
