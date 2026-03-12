import { notFound } from "next/navigation";
import { Metadata } from "next";
import { promises as fs } from "fs";
import path from "path";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

interface PageProps {
  params: Promise<{
    slug: string[];
  }>;
}

// 获取所有 MD 文件路径
async function getAllMdFiles(dir: string, basePath: string = ""): Promise<string[]> {
  const files: string[] = [];
  const entries = await fs.readdir(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relativePath = path.join(basePath, entry.name);

    if (entry.isDirectory()) {
      files.push(...await getAllMdFiles(fullPath, relativePath));
    } else if (entry.name.endsWith(".md")) {
      files.push(relativePath.replace(/\.md$/, ""));
    }
  }

  return files;
}

// 获取页面内容
async function getPageContent(slug: string[], lang: string = "en") {
  const slugPath = slug.join("/");
  const filePath = path.join(process.cwd(), "content", lang, `${slugPath}.md`);

  try {
    const source = await fs.readFile(filePath, "utf-8");
    return { source, filePath };
  } catch {
    return null;
  }
}

// 解析 frontmatter
function parseFrontmatter(source: string) {
  const frontmatterRegex = /^---\s*\n([\s\S]*?)\n---\s*\n([\s\S]*)$/;
  const match = source.match(frontmatterRegex);

  if (!match) {
    return { frontmatter: {}, content: source };
  }

  const frontmatterText = match[1];
  const content = match[2];

  const frontmatter: Record<string, string> = {};
  for (const line of frontmatterText.split("\n")) {
    const colonIndex = line.indexOf(":");
    if (colonIndex > 0) {
      const key = line.slice(0, colonIndex).trim();
      const value = line.slice(colonIndex + 1).trim().replace(/^["']|["']$/g, "");
      frontmatter[key] = value;
    }
  }

  return { frontmatter, content };
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const resolvedParams = await params;
  const pageContent = await getPageContent(resolvedParams.slug, "en");

  if (!pageContent) {
    return {};
  }

  const { frontmatter } = parseFrontmatter(pageContent.source);

  return {
    title: frontmatter.title,
    description: frontmatter.description,
  };
}

export async function generateStaticParams(): Promise<{ slug: string[] }[]> {
  const contentDir = path.join(process.cwd(), "content", "en");

  try {
    const files = await getAllMdFiles(contentDir);
    return files
      .filter(file => file !== "index")
      .map((file) => ({
        slug: file.split("/"),
      }));
  } catch {
    return [];
  }
}

export default async function PagePage({ params }: PageProps) {
  const resolvedParams = await params;
  const pageContent = await getPageContent(resolvedParams.slug, "en");

  if (!pageContent) {
    notFound();
  }

  const { frontmatter, content } = parseFrontmatter(pageContent.source);

  return (
    <article className="container py-10">
      <div className="prose prose-slate dark:prose-invert mx-auto max-w-3xl">
        {frontmatter.title && <h1 className="mb-4">{frontmatter.title}</h1>}
        {frontmatter.description && (
          <p className="text-lg text-muted-foreground mb-8">{frontmatter.description}</p>
        )}
        <ReactMarkdown remarkPlugins={[remarkGfm]}>
          {content}
        </ReactMarkdown>
      </div>
    </article>
  );
}
