import { useConfig } from 'vocs/hooks';
import { useLocation } from 'react-router-dom';

export function DocsLink() {
  const location = useLocation();
  const isZh = location.pathname.startsWith('/zh');
  const href = isZh ? '/zh/getting-started' : '/getting-started';
  
  return (
    <a href={href} className="nav-link">
      {isZh ? '文档' : 'Docs'}
    </a>
  );
}

export function BlogLink() {
  const location = useLocation();
  const isZh = location.pathname.startsWith('/zh');
  const href = isZh ? '/zh/blog' : '/blog';
  
  return (
    <a href={href} className="nav-link">
      {isZh ? '博客' : 'Blog'}
    </a>
  );
}
