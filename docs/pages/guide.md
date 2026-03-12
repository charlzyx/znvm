# Get Started

**znvm** is the fast, zero-config **node version manager** built with Zig. A lightweight **nvm alternative** that fixes **nvm-slow** issues.

## Installation

### Automatic Installation (Recommended)

Run the following command in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/charlzyx/znvm/main/install.sh | bash
```

This script will:
1.  Create a `~/.znvm` directory.
2.  Download the latest `znvm` binary for your platform.
3.  Add the necessary environment variables to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.).

### Manual Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/charlzyx/znvm.git ~/.znvm
    ```

2.  Add the following to your Shell configuration file (`~/.zshrc`, `~/.bashrc`, etc.):
    ```bash
    export ZNVM_ROOT="$HOME/.znvm"
    source "$ZNVM_ROOT/znvm.sh"

    # Recommended alias
    alias nv=znvm
    ```

3.  Restart your Shell or run `source ~/.zshrc`.

## Basic Usage

### Install a Node.js version
`znvm` supports SemVer. For example, `20` will automatically match the latest `v20.x.x`.

```bash
znvm install 20
znvm install v18.20.0
```

### Switch versions
```bash
znvm use 20          # Use specific version
znvm use             # Automatically read from .nvmrc
```

### List installed versions
```bash
znvm ls
```

### Set a default version
```bash
znvm default 20
```

### Uninstall a version
```bash
znvm uninstall 20
```

## Advanced Features

### .nvmrc & Auto Switch
`znvm` automatically detects `.nvmrc` files. You can enable or disable auto-switching on directory entry:

```bash
# Enable auto switch (default)
export ZNVM_AUTO_SWITCH=true

# Disable auto switch
export ZNVM_AUTO_SWITCH=false
```

### Mirror Acceleration
To speed up downloads in certain regions, you can set a mirror:

```bash
export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
```

### Global Package Isolation
Each Node.js version has its own independent global package environment. Global packages, npm cache, and Corepack (pnpm/yarn) are all isolated per version.

---

**Related:** nvm, fnm, nvm-slow, node version manager, node-version-manage
