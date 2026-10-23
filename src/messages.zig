const i18n = @import("i18n.zig");

const Msg = i18n.Msg;

pub const unknown_command = Msg{ .en = "Unknown command: {s}\n", .zh = "未知命令: {s}\n" };
pub const guide_needs_terminal = Msg{
    .en = "{s}: interactive guide needs a terminal.\nRun `{s} help` for commands.\n",
    .zh = "{s}: 交互向导需要终端.\n运行 `{s} help` 查看命令.\n",
};
pub const using = Msg{ .en = "Using {s}\n", .zh = "正在使用 {s}\n" };
pub const using_system = Msg{ .en = "Using system Node.js", .zh = "正在使用系统 Node.js" };
pub const deactivated = Msg{ .en = "Deactivated", .zh = "已停用" };
pub const bin_missing = Msg{ .en = "Version '{s}' is installed but bin/node is missing.\n", .zh = "版本 '{s}' 已安装, 但缺少 bin/node.\n" };
pub const bin_missing_plain = Msg{ .en = "Version '{s}' is installed but bin/node is missing.", .zh = "版本 '{s}' 已安装, 但缺少 bin/node." };
pub const alias_name_invalid = Msg{ .en = "Alias name '{s}' is invalid.\n", .zh = "别名 '{s}' 无效.\n" };
pub const alias_target_invalid = Msg{ .en = "Alias target is invalid.\n", .zh = "别名目标无效.\n" };
pub const no_iojs = Msg{ .en = "{s} does not manage io.js or the historical \"unstable\" line.\n", .zh = "{s} 不管理 io.js, 也不支持已停用的 unstable.\n" };
pub const alias_cycle = Msg{ .en = "The alias \"{s}\" leads to an infinite loop. Aborting.", .zh = "别名 \"{s}\" 形成了死循环, 已中止." };
pub const alias_cycle_nl = Msg{ .en = "The alias \"{s}\" leads to an infinite loop. Aborting.\n", .zh = "别名 \"{s}\" 形成了死循环, 已中止.\n" };
pub const not_installed_run = Msg{ .en = "Version '{s}' is not installed. Run '{s} install {s}' first.", .zh = "版本 '{s}' 未安装. 请先运行 '{s} install {s}'." };
pub const not_installed_run_nl = Msg{ .en = "Version '{s}' is not installed. Run '{s} install {s}' first.\n", .zh = "版本 '{s}' 未安装. 请先运行 '{s} install {s}'.\n" };
pub const invalid_version_file = Msg{ .en = "invalid version file: {s}\n", .zh = "版本文件无效: {s}\n" };
pub const found_version = Msg{ .en = "Found '{s}' with version <{s}>\n", .zh = "在 '{s}' 找到版本 <{s}>\n" };
pub const wrote_nvmrc = Msg{ .en = "Wrote version number ({s}) to .nvmrc\n", .zh = "已把版本号 ({s}) 写入 .nvmrc\n" };
pub const lts_needs_name = Msg{ .en = "Option \"--lts=\" needs an LTS name.", .zh = "选项 \"--lts=\" 需要 LTS 名称." };
pub const alias_needs_name = Msg{ .en = "Option \"--alias=\" needs a name.", .zh = "选项 \"--alias=\" 需要名称." };
pub const no_source_build = Msg{ .en = "{s} installs official Node.js binaries and does not compile from source (-s).\n", .zh = "{s} 只安装官方 Node.js 二进制, 不会从源码编译 (-s).\n" };
pub const option_needs_version = Msg{ .en = "Option \"{s}\" needs a version.", .zh = "选项 \"{s}\" 需要版本号." };
pub const option_needs_eq_version = Msg{ .en = "Option \"{s}\" needs =version.", .zh = "选项 \"{s}\" 需要 =版本号." };
pub const unsupported_option = Msg{ .en = "Unsupported option \"{s}\".", .zh = "不支持的选项 \"{s}\"." };
pub const usage_use = Msg{ .en = "Usage: {s} use [version]", .zh = "用法: {s} use [version]" };
pub const usage_install = Msg{ .en = "Usage: {s} install [version]", .zh = "用法: {s} install [version]" };
pub const usage_which = Msg{ .en = "Usage: {s} which [version]", .zh = "用法: {s} which [version]" };
pub const no_version_file = Msg{ .en = "{s}\nNo .nvmrc or .node-version file found.", .zh = "{s}\n没有找到 .nvmrc 或 .node-version." };
pub const system_nvmrc = Msg{ .en = "The system Node.js cannot be written to .nvmrc.\n", .zh = "系统 Node.js 不能写入 .nvmrc.\n" };
pub const system_install = Msg{ .en = "The system Node.js cannot be installed with {s}.\n", .zh = "不能用 {s} 安装系统 Node.js.\n" };
pub const no_active = Msg{ .en = "No active Node.js version.\n", .zh = "没有正在使用的 Node.js 版本.\n" };
pub const no_default = Msg{ .en = "No default version set.\n", .zh = "没有设置默认版本.\n" };
pub const npm_missing = Msg{ .en = "npm was not found for {s}.\n", .zh = "在 {s} 里没有找到 npm.\n" };
pub const npm_install_failed = Msg{ .en = "npm install -g failed for {s}.\n", .zh = "{s} 的 npm install -g 失败.\n" };
pub const reinstall_system = Msg{ .en = "Reinstalling packages from the system Node.js is not supported.\n", .zh = "不能从系统 Node.js 重装全局包.\n" };
pub const reinstall_current = Msg{ .en = "Can not reinstall packages from the current version of node.\n", .zh = "不能从当前 Node 版本重装全局包.\n" };
pub const reinstalling = Msg{ .en = "Reinstalling global packages from {s}...\n", .zh = "正在从 {s} 重装全局包...\n" };
pub const no_global_packages = Msg{ .en = "No installed global packages found...\n", .zh = "没有已安装的全局包...\n" };
pub const one_package_per_line = Msg{ .en = "Only one package per line is allowed in `{s}`.\n", .zh = "`{s}` 里一行只能写一个包.\n" };
pub const installing_default_packages = Msg{ .en = "Installing default global packages from {s}...\n", .zh = "正在从 {s} 安装默认全局包...\n" };
pub const could_not_resolve = Msg{ .en = "Could not resolve version '{s}'\n", .zh = "无法解析版本 '{s}'\n" };
pub const reinstall_from_installed = Msg{ .en = "If --reinstall-packages-from is provided, it must point to an installed version of node.\n", .zh = "如果提供了 --reinstall-packages-from, 它必须指向已安装的 Node 版本.\n" };
pub const already_installed = Msg{ .en = "Version {s} is already installed.\n", .zh = "版本 {s} 已经安装.\n" };
pub const installing = Msg{ .en = "Installing {s} ({s})...\n", .zh = "正在安装 {s} ({s})...\n" };
pub const no_cached_tarball = Msg{ .en = "No cached tarball for {s}. Run install once without --offline.\n", .zh = "没有 {s} 的缓存包. 请去掉 --offline 再安装一次.\n" };
pub const using_cached = Msg{ .en = "Using cached {s}\n", .zh = "使用缓存 {s}\n" };
pub const extracting = Msg{ .en = "Extracting...\n", .zh = "正在解压...\n" };
pub const extraction_failed = Msg{ .en = "Extraction failed.\n", .zh = "解压失败.\n" };
pub const installed = Msg{ .en = "Installed {s}\n", .zh = "已安装 {s}\n" };
pub const default_arrow = Msg{ .en = "default -> {s}\n", .zh = "default -> {s}\n" };
pub const alias_arrow = Msg{ .en = "{s} -> {s}\n", .zh = "{s} -> {s}\n" };
pub const no_versions = Msg{ .en = "No versions installed.\n", .zh = "没有已安装的版本.\n" };
pub const usage_ls = Msg{ .en = "Usage: {s} ls [version]", .zh = "用法: {s} ls [version]" };
pub const no_alias_flag = Msg{ .en = "`--no-alias` is not supported when a version is provided.", .zh = "指定版本时不支持 `--no-alias`." };
pub const usage_ls_remote = Msg{ .en = "Usage: {s} ls-remote [version]", .zh = "用法: {s} ls-remote [version]" };
pub const fetch_index = Msg{ .en = "error: Failed to fetch Node.js index ({s})", .zh = "error: 获取 Node.js 索引失败 ({s})" };
pub const fetch_index_nl = Msg{ .en = "error: Failed to fetch Node.js index ({s})\n", .zh = "error: 获取 Node.js 索引失败 ({s})\n" };
pub const fetch_index_plain = Msg{ .en = "Failed to fetch Node.js index ({s})\n", .zh = "获取 Node.js 索引失败 ({s})\n" };
pub const usage_uninstall = Msg{ .en = "Usage: {s} uninstall <version>\n", .zh = "用法: {s} uninstall <version>\n" };
pub const system_uninstall = Msg{ .en = "The system Node.js cannot be uninstalled with {s}.\n", .zh = "不能用 {s} 卸载系统 Node.js.\n" };
pub const version_not_installed = Msg{ .en = "Version '{s}' is not installed.\n", .zh = "版本 '{s}' 未安装.\n" };
pub const uninstalled = Msg{ .en = "Uninstalled {s}\n", .zh = "已卸载 {s}\n" };
pub const usage_alias = Msg{ .en = "Usage: {s} alias [name [target]]\n", .zh = "用法: {s} alias [name [target]]\n" };
pub const no_alias = Msg{ .en = "No alias found.\n", .zh = "没有别名.\n" };
pub const usage_unalias = Msg{ .en = "Usage: {s} unalias <name>\n", .zh = "用法: {s} unalias <name>\n" };
pub const alias_missing = Msg{ .en = "Alias '{s}' does not exist.\n", .zh = "别名 '{s}' 不存在.\n" };
pub const deleted_alias = Msg{ .en = "Deleted alias {s}\n", .zh = "已删除别名 {s}\n" };
pub const usage_default = Msg{ .en = "Usage: {s} default [version]\n", .zh = "用法: {s} default [version]\n" };
pub const system_node_missing = Msg{ .en = "System version of node not found.", .zh = "没有找到系统 node." };
pub const system_node_missing_nl = Msg{ .en = "System version of node not found.\n", .zh = "没有找到系统 node.\n" };
pub const usage_version = Msg{ .en = "Usage: {s} version [version]", .zh = "用法: {s} version [version]" };
pub const usage_version_remote = Msg{ .en = "Usage: {s} version-remote [version]\n", .zh = "用法: {s} version-remote [version]\n" };
pub const running_system = Msg{ .en = "Running system node\n", .zh = "正在运行系统 node\n" };
pub const running_node = Msg{ .en = "Running node {s}\n", .zh = "正在运行 node {s}\n" };
pub const usage_run_missing = Msg{ .en = "Usage: {s} {s} [version] [args...]\nNo .nvmrc or .node-version file found.\n", .zh = "用法: {s} {s} [version] [args...]\n没有找到 .nvmrc 或 .node-version.\n" };
pub const usage_exec = Msg{ .en = "Usage: {s} exec [version] <command> [args...]\n", .zh = "用法: {s} exec [version] <command> [args...]\n" };
pub const usage_reinstall = Msg{ .en = "Usage: {s} reinstall-packages <version>\n", .zh = "用法: {s} reinstall-packages <version>\n" };
pub const no_active_use_first = Msg{ .en = "No active Node.js version. Run `{s} use <version>` first.\n", .zh = "没有正在使用的 Node.js 版本. 请先运行 `{s} use <version>`.\n" };
pub const usage_latest_npm = Msg{ .en = "Usage: {s} install-latest-npm\n", .zh = "用法: {s} install-latest-npm\n" };
pub const usage_cache = Msg{ .en = "Usage: {s} cache dir|clear\n", .zh = "用法: {s} cache dir|clear\n" };
pub const cache_cleared = Msg{ .en = "{s} cache cleared.\n", .zh = "已清空 {s} 缓存.\n" };
pub const usage_deactivate = Msg{ .en = "Usage: {s} deactivate\n", .zh = "用法: {s} deactivate\n" };
pub const debug_version = Msg{ .en = "znvm version: {s}\n", .zh = "znvm 版本: {s}\n" };
pub const debug_dir = Msg{ .en = "NVM_DIR: {s}\n", .zh = "NVM_DIR: {s}\n" };
pub const debug_versions = Msg{ .en = "versions: {s}\n", .zh = "版本目录: {s}\n" };
pub const debug_mirror = Msg{ .en = "mirror: {s}\n", .zh = "镜像: {s}\n" };
pub const debug_platform = Msg{ .en = "platform: {s}-{s}\n", .zh = "平台: {s}-{s}\n" };
pub const debug_installed = Msg{ .en = "installed: {d}\n", .zh = "已安装: {d}\n" };
pub const debug_prefix = Msg{ .en = "npm prefix: {s}\n", .zh = "npm 前缀: {s}\n" };
pub const debug_prefix_per_node = Msg{ .en = "npm prefix: per Node version\n", .zh = "npm 前缀: 随 Node 版本\n" };

pub const registry_usage = Msg{
    .en =
        \\registry show
        \\registry set-default <url>
        \\registry add <@scope> <url>
        \\registry remove <@scope>
        \\registry china
        \\registry official
        \\registry sync
        \\
    ,
    .zh =
        \\registry show
        \\registry set-default <url>
        \\registry add <@scope> <url>
        \\registry remove <@scope>
        \\registry china
        \\registry official
        \\registry sync
        \\
    ,
};

pub const help = Msg{
    .en =
        \\{s} - Node.js version manager
        \\
        \\Usage: {s} <command> [args]
        \\
        \\  install [version]      install Node
        \\  use [version]          select a version
        \\  exec [version] <cmd>   run one command
        \\  run [version] [args]   run node
        \\  ls, list [version]     installed versions
        \\  ls-remote [version]    remote versions
        \\  current                active version
        \\  which [version]        path to node
        \\  version [version]      resolve a version
        \\  version-remote         resolve a remote version
        \\  alias [name [target]]  list or set an alias
        \\  unalias <name>         delete an alias
        \\  default [version]      default alias
        \\  uninstall, rm <version>
        \\  reinstall-packages <version>
        \\  install-latest-npm
        \\  cache dir|clear
        \\  deactivate
        \\  guide, interactive
        \\  registry [show|set-default|add|remove|china|official|sync]
        \\  mirror [ls|use|set|reset|test]
        \\  env                    shell setup
        \\  debug
        \\  lang                   print zh or en
        \\  --llm                  agent guide
        \\  --version, -v
        \\  help
        \\
        \\Env: NVM_DIR  NVM_NODEJS_ORG_MIRROR  NVM_LANG=zh|en  NVM_MIRROR=auto|china|official
        \\
    ,
    .zh =
        \\{s} - Node.js 版本管理
        \\
        \\用法: {s} <command> [args]
        \\
        \\  install [version]      安装 Node
        \\  use [version]          选择版本
        \\  exec [version] <cmd>   用该版本运行一条命令
        \\  run [version] [args]   运行 node
        \\  ls, list [version]     已安装版本
        \\  ls-remote [version]    远程版本
        \\  current                当前版本
        \\  which [version]        node 路径
        \\  version [version]      解析版本
        \\  version-remote         解析远程版本
        \\  alias [name [target]]  列出或设置别名
        \\  unalias <name>         删除别名
        \\  default [version]      默认别名
        \\  uninstall, rm <version>
        \\  reinstall-packages <version>
        \\  install-latest-npm
        \\  cache dir|clear
        \\  deactivate
        \\  guide, interactive
        \\  registry [show|set-default|add|remove|china|official|sync]
        \\  mirror [ls|use|set|reset|test]
        \\  env                    shell 配置
        \\  debug
        \\  lang                   打印 zh 或 en
        \\  --llm                  代理说明
        \\  --version, -v
        \\  help
        \\
        \\环境变量: NVM_DIR  NVM_NODEJS_ORG_MIRROR  NVM_LANG=zh|en  NVM_MIRROR=auto|china|official
        \\
    ,
};

pub const nrm_help = Msg{
    .en =
        \\nrm - registry manager
        \\
        \\Usage: nrm <command>
        \\
        \\  ls
        \\  use <name|auto>
        \\  current [-u|--show-url]
        \\  add <name> <url>
        \\  del <name>
        \\  test [name]
        \\  scope ls
        \\  scope add <@scope> <url>
        \\  scope del <@scope>
        \\  lang
        \\  --llm
        \\  --version, -v
        \\  help
        \\
        \\Download mirrors are the nvm mirror command.
        \\Env: NVM_DIR  NVM_LANG=zh|en
        \\
    ,
    .zh =
        \\nrm - 源管理
        \\
        \\用法: nrm <command>
        \\
        \\  ls
        \\  use <name|auto>
        \\  current [-u|--show-url]
        \\  add <name> <url>
        \\  del <name>
        \\  test [name]
        \\  scope ls
        \\  scope add <@scope> <url>
        \\  scope del <@scope>
        \\  lang
        \\  --llm
        \\  --version, -v
        \\  help
        \\
        \\下载镜像使用 nvm mirror.
        \\环境变量: NVM_DIR  NVM_LANG=zh|en
        \\
    ,
};

pub const mirror_help = Msg{
    .en =
        \\nvm mirror - download mirrors
        \\
        \\  ls
        \\  use <china|official|auto>
        \\  set <name> <url>
        \\  reset
        \\  test [name]
        \\
        \\china writes the npmmirror hosts. official clears them.
        \\auto keeps the faster host for each tool.
        \\--json works for ls and test.
        \\
    ,
    .zh =
        \\nvm mirror - 下载镜像
        \\
        \\  ls
        \\  use <china|official|auto>
        \\  set <name> <url>
        \\  reset
        \\  test [name]
        \\
        \\china 写入 npmmirror 地址. official 清掉这些地址.
        \\auto 为每个工具留下更快的一边.
        \\ls 和 test 支持 --json.
        \\
    ,
};

pub const scope_shape = Msg{ .en = "error: Scope must look like @company.", .zh = "error: scope 必须类似 @company." };
pub const registry_url = Msg{ .en = "error: Registry must be an http:// or https:// URL.", .zh = "error: 源地址必须是 http:// 或 https://." };
pub const scope_missing = Msg{ .en = "error: That scope is not in the map.", .zh = "error: 映射里没有这个 scope." };
pub const no_home = Msg{ .en = "error: HOME is not set.", .zh = "error: 没有设置 HOME." };
pub const no_map = Msg{ .en = "error: No registry map yet. Set a default or a scope first.", .zh = "error: 还没有源映射. 请先设置默认源或 scope." };
pub const bad_registry_name = Msg{ .en = "error: registry name must be letters, digits, '-', '_', or '.'.", .zh = "error: 源名字只能包含字母, 数字, '-', '_' 或 '.'." };
pub const curl_nrm = Msg{ .en = "error: curl is required for nrm test.", .zh = "error: nrm test 需要 curl." };
pub const registry_failed = Msg{ .en = "error: registry failed: {s}", .zh = "error: 源操作失败: {s}" };
pub const no_registry_map = Msg{ .en = "No registry map in {s}\n", .zh = "{s} 里没有源映射\n" };
pub const not_a_registry = Msg{ .en = "error: {s} is not a registry.\n", .zh = "error: {s} 不是已登记的源.\n" };
pub const not_a_registry_plain = Msg{ .en = "error: {s} is not a registry.", .zh = "error: {s} 不是已登记的源." };
pub const registry_changed = Msg{ .en = "The registry has been changed to '{s}'.\n", .zh = "源已切换为 '{s}'.\n" };
pub const auto_reserved = Msg{ .en = "error: auto is reserved.\n", .zh = "error: auto 是保留名.\n" };
pub const builtin_registry = Msg{ .en = "error: {s} is a built-in registry.\n", .zh = "error: {s} 是内置源.\n" };
pub const added_name = Msg{ .en = "added {s}\n", .zh = "已添加 {s}\n" };
pub const deleted_name = Msg{ .en = "deleted {s}\n", .zh = "已删除 {s}\n" };
pub const no_scopes = Msg{ .en = "No scopes.\n", .zh = "没有 scope.\n" };
pub const no_registry_responded = Msg{ .en = "error: no registry responded.\n", .zh = "error: 没有源响应.\n" };
pub const wrote_path = Msg{ .en = "Wrote {s}\n", .zh = "已写入 {s}\n" };
pub const sync_writes = Msg{ .en = "Sync writes:\n  {s}\n  {s}\n  {s}\n  {s}\n  {s}\n", .zh = "将写入:\n  {s}\n  {s}\n  {s}\n  {s}\n  {s}\n" };
pub const default_url = Msg{ .en = "default {s}\n", .zh = "默认 {s}\n" };
pub const default_unset = Msg{ .en = "default (not set)\n", .zh = "默认 (未设置)\n" };

pub const mirror_url = Msg{ .en = "error: mirror must be an http:// or https:// URL.", .zh = "error: 镜像地址必须是 http:// 或 https://." };
pub const curl_mirror = Msg{ .en = "error: curl is required for nvm mirror test.", .zh = "error: nvm mirror test 需要 curl." };
pub const mirror_failed = Msg{ .en = "error: mirror failed: {s}", .zh = "error: 镜像操作失败: {s}" };
pub const mirror_profile = Msg{ .en = "error: mirror profile must be china, official, or auto.\n", .zh = "error: 镜像配置只能是 china, official 或 auto.\n" };
pub const mirror_env = Msg{ .en = "error: NVM_MIRROR must be china or official.\n", .zh = "error: NVM_MIRROR 只能是 china 或 official.\n" };
pub const mirror_kept = Msg{ .en = "mirror config already set\n", .zh = "镜像配置已存在\n" };
pub const mirror_line = Msg{ .en = "mirror: {s}\n", .zh = "镜像: {s}\n" };
pub const mirror_unchanged = Msg{ .en = "mirror: unchanged\n", .zh = "镜像: 未变\n" };
pub const mirror_npmrc_warn = Msg{
    .en = "{d} npmrc mirror keys may trigger npm warnings\n",
    .zh = "注意: npmrc 镜像键 {d} 个，npm 可能报警告\n",
};
pub const profile_line = Msg{ .en = "profile {s}\n", .zh = "配置 {s}\n" };
pub const unset_mirror = Msg{ .en = "  {s} (unset)\n", .zh = "  {s} (未设置)\n" };
pub const mirrors_changed = Msg{ .en = "The mirrors have been changed to '{s}'.\n", .zh = "镜像已切换为 '{s}'.\n" };
pub const mirrors_changed_auto = Msg{ .en = "The mirrors have been changed to 'auto'.\n", .zh = "镜像已切换为 'auto'.\n" };
pub const not_a_mirror = Msg{ .en = "error: {s} is not a mirror.\n", .zh = "error: {s} 不是镜像名.\n" };
pub const not_a_mirror_plain = Msg{ .en = "error: {s} is not a mirror.", .zh = "error: {s} 不是镜像名." };
pub const set_mirror = Msg{ .en = "set {s}\n", .zh = "已设置 {s}\n" };
pub const mirrors_reset = Msg{ .en = "mirrors reset\n", .zh = "镜像已重置\n" };
pub const no_mirror_responded = Msg{ .en = "error: no mirror responded.\n", .zh = "error: 没有镜像响应.\n" };
pub const removed_path = Msg{ .en = "Removed {s}\n", .zh = "已删除 {s}\n" };
