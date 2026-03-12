'use client';

import { usePathname } from 'next/navigation';

export function DocsLink() {
  const pathname = usePathname() || '/';
  const isZh = pathname.startsWith('/zh');
  const href = isZh ? '/zh/getting-started' : '/getting-started';

  return (
    <a href={href} className="nav-link">
      {isZh ? '文档' : 'Docs'}
    </a>
  );
}

export function BlogLink() {
  const pathname = usePathname() || '/';
  const isZh = pathname.startsWith('/zh');
  const href = isZh ? '/zh/blog' : '/blog';

  return (
    <a href={href} className="nav-link">
      {isZh ? '博客' : 'Blog'}
    </a>
  );
}
