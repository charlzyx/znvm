# Changelog

All notable changes to the znvm documentation site will be documented in this file.

## [Unreleased]

## [1.0.0] - 2025-03-12

### Added
- Initial documentation site setup with Vocs
- Multi-language support: English (default) and 简体中文
- SEO optimization with keywords: nvm, fnm, nvm-slow, node-version-manage
- Google Analytics integration (G-8K2GC0YBD7)
- Landing pages with performance benchmarks
- Installation and usage guides

### Changed
- Set English (`/`) as default language
- Configured top navigation for language switching

## Documentation Structure

```
docs/
├── pages/
│   ├── index.md          # English homepage (default)
│   ├── guide.md          # English guide
│   ├── why-zig.md        # English why zig
│   ├── en/               # English subdirectory
│   │   ├── index.md
│   │   ├── guide.md
│   │   └── why-zig.md
│   └── zh/               # Chinese subdirectory
│       ├── index.md
│       ├── guide.md
│       └── why-zig.md
└── vocs.config.tsx       # Vocs configuration
```
