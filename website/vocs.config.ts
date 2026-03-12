import { defineConfig } from 'vocs'

export default defineConfig({
  title: 'znvm.dev',
  description: 'znvm: A blazingly fast Node.js version manager built with Zig. The best nvm alternative that solves nvm-slow. Lightweight node version manager for Unix.',
  baseUrl: 'https://znvm.dev',
  ogImageUrl: 'https://vocs.dev/api/og?logo=%logo&title=%title&description=%description',
  theme: {
    accentColor: '#f7931e', // Zig-inspired orange
  },
  sidebar: {
    '/': [
      {
        text: 'Introduction',
        link: '/',
      },
      {
        text: 'Get Started',
        link: '/getting-started',
      },
    ],
    '/zh/': [
      {
        text: '简介',
        link: '/zh/',
      },
      {
        text: '快速开始',
        link: '/zh/getting-started',
      },
    ],
    '/blog/': [
      {
        text: 'Blog',
        link: '/blog',
      },
      {
        text: 'Why Zig?',
        link: '/blog/why-zig',
      },
    ],
    '/zh/blog/': [
      {
        text: '博客',
        link: '/zh/blog',
      },
      {
        text: '为什么选择 Zig？',
        link: '/zh/blog/why-zig',
      },
    ],
  },
  topNav: [
    { 
      text: 'Docs', 
      link: '/getting-started',
    },
    { 
      text: 'Blog', 
      link: '/blog',
    },
    {
      text: 'Languages',
      items: [
        { text: 'English', link: '/' },
        { text: '简体中文', link: '/zh/' },
      ],
    },
  ],
  socials: [
    { icon: 'github', link: 'https://github.com/charlzyx/znvm' },
  ],
})
