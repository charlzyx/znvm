import React from "react"
import { MDXComponents } from "mdx/types"

export const MdxComponents: MDXComponents = {
  // Text elements
  p: ({ children }) => (
    <p className="mb-4 leading-7 [&:not(:first-child)]:mt-6">
      {children}
    </p>
  ),
  
  // Headings
  h1: ({ children }) => (
    <h1 className="mt-2 scroll-m-20 text-4xl font-bold tracking-tight">
      {children}
    </h1>
  ),
  h2: ({ children }) => (
    <h2 className="mt-12 scroll-m-20 border-b pb-1 text-2xl font-semibold tracking-tight first:mt-0">
      {children}
    </h2>
  ),
  h3: ({ children }) => (
    <h3 className="mt-8 scroll-m-20 text-xl font-semibold tracking-tight">
      {children}
    </h3>
  ),
  h4: ({ children }) => (
    <h4 className="mt-8 scroll-m-20 text-lg font-semibold tracking-tight">
      {children}
    </h4>
  ),
  h5: ({ children }) => (
    <h5 className="mt-8 scroll-m-20 text-base font-semibold tracking-tight">
      {children}
    </h5>
  ),
  h6: ({ children }) => (
    <h6 className="mt-8 scroll-m-20 text-sm font-semibold tracking-tight">
      {children}
    </h6>
  ),

  // Lists
  ul: ({ children }) => (
    <ul className="my-6 ml-6 list-disc [&>li]:mt-2">
      {children}
    </ul>
  ),
  ol: ({ children }) => (
    <ol className="my-6 ml-6 list-decimal [&>li]:mt-2">
      {children}
    </ol>
  ),
  li: ({ children }) => (
    <li className="mt-2">
      {children}
    </li>
  ),

  // Code
  code: ({ children, className }) => (
    <code className={`relative rounded bg-muted px-[0.3rem] py-[0.2rem] font-mono text-sm font-semibold ${className || ""}`}>
      {children}
    </code>
  ),
  pre: ({ children }) => (
    <pre className="mb-4 mt-6 overflow-x-auto rounded-lg border bg-slate-950 p-4 text-slate-50">
      {children}
    </pre>
  ),

  // Links
  a: ({ children, href }) => (
    <a href={href} className="font-medium underline underline-offset-4 hover:text-primary">
      {children}
    </a>
  ),

  // Blockquote
  blockquote: ({ children }) => (
    <blockquote className="mt-6 border-l-2 border-primary pl-6 italic text-muted-foreground">
      {children}
    </blockquote>
  ),

  // Horizontal rule
  hr: () => (
    <hr className="my-4 md:my-8" />
  ),

  // Table
  table: ({ children }) => (
    <div className="my-6 w-full overflow-y-auto">
      <table className="w-full border-collapse">
        {children}
      </table>
    </div>
  ),
  thead: ({ children }) => (
    <thead className="border-b bg-muted/50">
      {children}
    </thead>
  ),
  tbody: ({ children }) => (
    <tbody>
      {children}
    </tbody>
  ),
  tr: ({ children }) => (
    <tr className="border-b hover:bg-muted/50">
      {children}
    </tr>
  ),
  th: ({ children }: { children: React.ReactNode }) => (
    <th className="px-4 py-2 text-left font-semibold">
      {children}
    </th>
  ),
  td: ({ children }: { children: React.ReactNode }) => (
    <td className="px-4 py-2">
      {children}
    </td>
  ),

  // Images
  img: ({ src, alt }: { src?: string; alt?: string }) => (
    <img 
      src={src} 
      alt={alt} 
      className="my-6 max-w-full rounded-lg border"
    />
  ),

  // Strong and emphasis
  strong: ({ children }) => (
    <strong className="font-semibold">
      {children}
    </strong>
  ),
  em: ({ children }) => (
    <em className="italic">
      {children}
    </em>
  ),
}
