import { defineConfig } from 'vocs'

export default defineConfig({
  title: 'znvm - Fast Node.js Version Manager',
  description: 'znvm: A blazingly fast Node.js version manager built with Zig. The best nvm alternative that solves nvm-slow. Lightweight node version manager for Unix.',
  baseUrl: 'https://znvm.dev',
  ogImageUrl: 'https://vocs.dev/api/og?logo=%logo&title=%title&description=%description',
  theme: {
    accentColor: '#f7931e', // Zig-inspired orange
  },
  head: (
    <>
      <meta name="keywords" content="znvm, nvm, fnm, nvm-slow, node version manager, node-version-manage, nodejs version manager, zig, fast, lightweight, unix, macos, linux" />
      <meta name="author" content="charlzyx" />
      <meta property="og:type" content="website" />
      <meta property="og:site_name" content="znvm" />
      <meta name="twitter:card" content="summary_large_image" />
      <script async src="https://www.googletagmanager.com/gtag/js?id=G-8K2GC0YBD7"></script>
      <script>{`
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());
        gtag('config', 'G-8K2GC0YBD7');
      `}</script>
    </>
  ),
  sidebar: {
    '/': [
      { text: 'Introduction', link: '/' },
      { text: 'Get Started', link: '/guide' },
      { text: 'Why Zig?', link: '/why-zig' },
    ],
    '/en/': [
      { text: 'Introduction', link: '/en/' },
      { text: 'Get Started', link: '/en/guide' },
      { text: 'Why Zig?', link: '/en/why-zig' },
    ],
    '/zh/': [
      { text: '简介', link: '/zh/' },
      { text: '快速开始', link: '/zh/guide' },
      { text: '为什么选择 Zig?', link: '/zh/why-zig' },
    ],
  },
  topNav: [
    { text: 'English', link: '/' },
    { text: '简体中文', link: '/zh/' },
  ],
  socials: [
    { icon: 'github', link: 'https://github.com/charlzyx/znvm' },
  ],
})
