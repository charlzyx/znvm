import { useLocation } from 'react-router';

export function LanguageSwitch() {
  const location = useLocation();
  const pathname = location.pathname;
  
  // Check if we're on a Chinese page
  const isZh = pathname.startsWith('/zh');
  
  // Generate the opposite language link
  let targetPath: string;
  if (isZh) {
    // From Chinese to English: remove /zh prefix
    targetPath = pathname.replace(/^\/zh/, '') || '/';
  } else {
    // From English to Chinese: add /zh prefix
    targetPath = '/zh' + pathname;
  }
  
  const text = isZh ? '🇺🇸 English' : '🇨🇳 中文';
  
  return (
    <div style={{ 
      marginBottom: '1rem', 
      padding: '0.75rem 1rem',
      backgroundColor: 'var(--vocs-color-backgroundAccent)',
      borderRadius: '8px',
      fontSize: '0.875rem'
    }}>
      <a 
        href={targetPath}
        style={{ 
          color: 'var(--vocs-color-textAccent)',
          textDecoration: 'none',
          fontWeight: 500
        }}
      >
        {text} →
      </a>
    </div>
  );
}
