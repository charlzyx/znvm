const std = @import("std");
const mem = std.mem;

const i18n = @import("i18n.zig");
const messages = @import("messages.zig");
const util = @import("util.zig");

const stdout = util.stdout;

fn zhNow() bool {
    i18n.init(std.heap.c_allocator);
    return i18n.isZh();
}

pub fn printNvm(program_name: []const u8) !void {
    if (zhNow()) {
        try stdout(
            \\用法: {s} <命令> [参数]
            \\
            \\命令:
            \\  install [版本]          安装 Node
            \\  use [版本]              切换版本
            \\  exec [版本] <命令>      用指定版本执行命令
            \\  run [版本] [参数]       用指定版本运行 node
            \\  ls [版本]               列出已安装版本
            \\  ls-remote [版本]        列出远程版本
            \\  current                 当前版本
            \\  which [版本]            node 路径
            \\  version [版本]          当前或解析版本
            \\  version-remote [版本]   解析远程版本
            \\  alias [名字 [目标]]     查看或设置别名
            \\  unalias <名字>          删除别名
            \\  default [版本]          设置默认别名
            \\  uninstall <版本>        卸载版本
            \\  reinstall-packages <版本>  复制全局包
            \\  install-latest-npm      安装 npm@latest
            \\  cache dir|clear         缓存目录或清空
            \\  deactivate              退出当前版本
            \\  guide, interactive      打开菜单
            \\  registry [子命令]       源和 scope
            \\  mirror [ls|use|set|reset|test]  下载镜像
            \\  env                     打印 shell 配置
            \\  debug                   打印路径
            \\  help [命令]             显示帮助
            \\  lang                    打印 zh 或 en
            \\
            \\选项:
            \\  --lts[=name] --default --offline --silent --save --json --yes --llm --version
            \\
            \\环境变量:
            \\  NVM_DIR                 数据目录, 默认 ~/.nvm
            \\  NVM_NODEJS_ORG_MIRROR   Node 下载地址
            \\  NVM_LANG                语言, zh 或 en
            \\  NVM_MIRROR              安装时 china 或 official
            \\
        , .{program_name});
        return;
    }
    try stdout(
        \\Usage: {s} <command> [args]
        \\
        \\Commands:
        \\  install [version]       install Node
        \\  use [version]           activate a version
        \\  exec [version] <cmd>    run a command
        \\  run [version] [args]    run node
        \\  ls [version]            list installed
        \\  ls-remote [version]     list remote
        \\  current                 active version
        \\  which [version]         path to node
        \\  version [version]       active or resolve a version
        \\  version-remote [version]  resolve a remote version
        \\  alias [name [target]]   list or set an alias
        \\  unalias <name>          delete an alias
        \\  default [version]       set the default alias
        \\  uninstall <version>     remove a version
        \\  reinstall-packages <version>  copy global packages
        \\  install-latest-npm      install npm@latest
        \\  cache dir|clear         cache path or clear
        \\  deactivate              drop the active version
        \\  guide, interactive      open the menu
        \\  registry [sub]          registry and scopes
        \\  mirror [ls|use|set|reset|test]  download mirrors
        \\  env                     print shell setup
        \\  debug                   print paths
        \\  help [command]          show help
        \\  lang                    print zh or en
        \\
        \\Options:
        \\  --lts[=name] --default --offline --silent --save --json --yes --llm --version
        \\
        \\Environment:
        \\  NVM_DIR                 data directory (default ~/.nvm)
        \\  NVM_NODEJS_ORG_MIRROR   Node download host
        \\  NVM_LANG                language, zh or en
        \\  NVM_MIRROR              install preset, china or official
        \\
    , .{program_name});
}

pub fn printNrm() !void {
    if (zhNow()) {
        try stdout(
            \\nrm - 源管理
            \\
            \\用法: nrm <命令> [参数]
            \\
            \\命令:
            \\  ls                          列出源
            \\  current [-u|--show-url]     当前名字或地址
            \\  use [名字|auto]             切换源
            \\  add <名字> <url> [home]     添加自定义源
            \\  del [名字]                  删除自定义源
            \\  login <名字> [base64]       设置授权
            \\  set-hosted-repo <名字> <repo>  设置发布 repository
            \\  set-scope <@scope> <url>    绑定 scope 到源
            \\  del-scope <@scope>          删除 scope 路由
            \\  set <名字> -a <attr> -v <value>  设置源属性
            \\  rename <名字> <新名字>      重命名自定义源
            \\  home <名字> [browser]       打开源主页
            \\  test [名字]                 测量延迟
            \\  scope ls|add|del            管理 @scope 路由
            \\  help [命令]                 显示帮助
            \\  lang                        打印 zh 或 en
            \\  -V, --version               版本
            \\
            \\环境变量: NVM_DIR  NVM_LANG=zh|en
            \\下载镜像: nvm mirror
            \\
        , .{});
        return;
    }
    try stdout(
        \\nrm - registry manager
        \\
        \\Usage: nrm <command> [args]
        \\
        \\Commands:
        \\  ls                          list registries
        \\  current [-u|--show-url]     current name or URL
        \\  use [name|auto]             switch registry
        \\  add <name> <url> [home]     add custom registry
        \\  del [name]                  delete custom registry
        \\  login <name> [base64]       set authorization
        \\  set-hosted-repo <name> <repo>  set publish repository
        \\  set-scope <@scope> <url>    bind scope to registry
        \\  del-scope <@scope>          remove scope route
        \\  set <name> -a <attr> -v <value>  set registry attribute
        \\  rename <name> <newName>     rename custom registry
        \\  home <name> [browser]       open registry home page
        \\  test [name]                 probe latency
        \\  scope ls|add|del            manage @scope routes
        \\  help [command]              show help
        \\  lang                        print zh or en
        \\  -V, --version               tool version
        \\
        \\Environment: NVM_DIR  NVM_LANG=zh|en
        \\Download hosts: nvm mirror
        \\
    , .{});
}

const NrmTopic = struct {
    name: []const u8,
    aliases: []const []const u8 = &.{},
    usage: []const u8,
    en: []const u8,
    zh: []const u8,
};

const nrm_topics = [_]NrmTopic{
    .{ .name = "ls", .aliases = &.{ "list" }, .usage = "ls", .en = "List all registries.", .zh = "列出全部源." },
    .{ .name = "current", .usage = "current [-u|--show-url]", .en = "Show current registry name or URL.", .zh = "显示当前源名字或地址." },
    .{ .name = "use", .usage = "use [name|auto]", .en = "Change current registry.", .zh = "切换当前源." },
    .{ .name = "add", .usage = "add <name> <url> [home]", .en = "Add a custom registry.", .zh = "添加自定义源." },
    .{ .name = "del", .aliases = &.{ "rm" }, .usage = "del [name]", .en = "Delete custom registries.", .zh = "删除自定义源." },
    .{ .name = "login", .usage = "login <name> [base64]", .en = "Set authorization for a registry.", .zh = "设置源授权." },
    .{ .name = "set-hosted-repo", .usage = "set-hosted-repo <name> <repo>", .en = "Set publish repository.", .zh = "设置发布 repository." },
    .{ .name = "set-scope", .usage = "set-scope <@scope> <url>", .en = "Associate a scope with a registry.", .zh = "为 scope 绑定源." },
    .{ .name = "del-scope", .usage = "del-scope <@scope>", .en = "Remove a scope route.", .zh = "删除 scope 路由." },
    .{ .name = "set", .usage = "set <name> -a <attr> -v <value>", .en = "Set a custom registry attribute.", .zh = "设置自定义源属性." },
    .{ .name = "rename", .usage = "rename <name> <newName>", .en = "Rename a custom registry.", .zh = "重命名自定义源." },
    .{ .name = "home", .usage = "home <name> [browser]", .en = "Open registry home page.", .zh = "打开源主页." },
    .{ .name = "test", .usage = "test [registry]", .en = "Show response time.", .zh = "显示响应时间." },
    .{ .name = "scope", .usage = "scope ls|add|del", .en = "Manage @scope routes (znvm).", .zh = "管理 @scope 路由 (znvm)." },
    .{ .name = "help", .aliases = &.{ "--help", "-h" }, .usage = "help [command]", .en = "Show help.", .zh = "显示帮助." },
    .{ .name = "lang", .usage = "lang", .en = "Print zh or en.", .zh = "打印 zh 或 en." },
};

fn nrmTopicMatches(topic: NrmTopic, raw: []const u8) bool {
    if (mem.eql(u8, topic.name, raw)) return true;
    for (topic.aliases) |alias| {
        if (mem.eql(u8, alias, raw)) return true;
    }
    return false;
}

pub fn printNrmCommand(raw: []const u8) !bool {
    const name = mem.trim(u8, raw, " \t");
    for (nrm_topics) |topic| {
        if (!nrmTopicMatches(topic, name)) continue;
        const chinese = zhNow();
        const label = if (chinese) "用法" else "Usage";
        const note = if (chinese) topic.zh else topic.en;
        try stdout("{s}: nrm {s}\n{s}\n", .{ label, topic.usage, note });
        return true;
    }
    return false;
}

pub fn printMirror(program_name: []const u8) !void {
    if (zhNow()) {
        try stdout(
            \\用法: {s} mirror <命令>
            \\
            \\命令:
            \\  ls                         列出地址
            \\  use <china|official|auto>  选择一套
            \\  set <名字> <url>           设置一个
            \\  reset                      清空
            \\  test [名字]                测量延迟
            \\
            \\环境变量:
            \\  NVM_DIR    数据目录
            \\  NVM_LANG   语言, zh 或 en
            \\
        , .{program_name});
        return;
    }
    try stdout(
        \\Usage: {s} mirror <command>
        \\
        \\Commands:
        \\  ls                         list hosts
        \\  use <china|official|auto>  choose a preset
        \\  set <name> <url>           set one host
        \\  reset                      clear hosts
        \\  test [name]                measure latency
        \\
        \\Environment:
        \\  NVM_DIR    data directory
        \\  NVM_LANG   language, zh or en
        \\
    , .{program_name});
}

const Topic = struct {
    name: []const u8,
    aliases: []const []const u8 = &.{},
    usage: []const u8,
    en: []const u8,
    zh: []const u8,
};

const topics = [_]Topic{
    .{ .name = "install", .usage = "install [version]", .en = "Install Node. --lts[=name] --default --offline --save", .zh = "安装 Node. --lts[=name] --default --offline --save" },
    .{ .name = "use", .usage = "use [version]", .en = "Activate a version. --silent --save", .zh = "切换版本. --silent --save" },
    .{ .name = "exec", .usage = "exec [version] <command> [args]", .en = "Run a command with a version.", .zh = "用指定版本执行命令." },
    .{ .name = "run", .usage = "run [version] [args]", .en = "Run node with a version.", .zh = "用指定版本运行 node." },
    .{ .name = "ls", .aliases = &.{ "list" }, .usage = "ls [version]", .en = "List installed versions. --no-alias", .zh = "列出已安装版本. --no-alias" },
    .{ .name = "ls-remote", .aliases = &.{ "list-remote" }, .usage = "ls-remote [version]", .en = "List remote versions. --lts", .zh = "列出远程版本. --lts" },
    .{ .name = "current", .usage = "current", .en = "Print the active version.", .zh = "打印当前版本." },
    .{ .name = "which", .usage = "which [version]", .en = "Print the path to node.", .zh = "打印 node 路径." },
    .{ .name = "version", .usage = "version [version]", .en = "Resolve a version.", .zh = "解析版本." },
    .{ .name = "version-remote", .usage = "version-remote [version]", .en = "Resolve a remote version.", .zh = "解析远程版本." },
    .{ .name = "alias", .usage = "alias [name [target]]", .en = "List aliases, or set one.", .zh = "列出别名, 或设置一个." },
    .{ .name = "unalias", .usage = "unalias <name>", .en = "Delete an alias.", .zh = "删除别名." },
    .{ .name = "default", .usage = "default [version]", .en = "Set the default alias.", .zh = "设置默认别名." },
    .{ .name = "uninstall", .aliases = &.{ "rm" }, .usage = "uninstall <version>", .en = "Remove an installed version.", .zh = "卸载已安装版本." },
    .{ .name = "reinstall-packages", .aliases = &.{ "copy-packages" }, .usage = "reinstall-packages <version>", .en = "Copy global packages from a version.", .zh = "从某个版本复制全局包." },
    .{ .name = "install-latest-npm", .usage = "install-latest-npm", .en = "Install npm@latest for the active version.", .zh = "为当前版本安装 npm@latest." },
    .{ .name = "cache", .aliases = &.{ "clear-cache" }, .usage = "cache dir|clear", .en = "Print the cache path, or clear it.", .zh = "打印缓存目录, 或清空." },
    .{ .name = "deactivate", .usage = "deactivate", .en = "Drop the active version. --silent", .zh = "退出当前版本. --silent" },
    .{ .name = "guide", .aliases = &.{ "interactive" }, .usage = "guide", .en = "Open the menu.", .zh = "打开菜单." },
    .{ .name = "registry", .usage = "registry <show|set-default|add|remove|china|official|sync>", .en = "Default registry and scopes. add <@scope> <url>", .zh = "默认源和 scope. add <@scope> <url>" },
    .{ .name = "mirror", .usage = "mirror <ls|use|set|reset|test>", .en = "Download mirrors. use <china|official|auto>", .zh = "下载镜像. use <china|official|auto>" },
    .{ .name = "env", .usage = "env", .en = "Print shell setup.", .zh = "打印 shell 配置." },
    .{ .name = "debug", .usage = "debug", .en = "Print paths and the tool version.", .zh = "打印路径和工具版本." },
    .{ .name = "help", .aliases = &.{ "--help", "-h" }, .usage = "help [command]", .en = "Show this screen, or one command.", .zh = "显示本页, 或一条命令." },
};

fn topicMatches(topic: Topic, raw: []const u8) bool {
    if (mem.eql(u8, topic.name, raw)) return true;
    for (topic.aliases) |alias| {
        if (mem.eql(u8, alias, raw)) return true;
    }
    return false;
}

pub fn printCommand(program_name: []const u8, raw: []const u8) !bool {
    const name = mem.trim(u8, raw, " \t");
    for (topics) |topic| {
        if (!topicMatches(topic, name)) continue;
        const chinese = zhNow();
        const label = if (chinese) "用法" else "Usage";
        const note = if (chinese) topic.zh else topic.en;
        try stdout("{s}: {s} {s}\n{s}\n", .{ label, program_name, topic.usage, note });
        return true;
    }
    return false;
}

pub fn unknownCommand(raw: []const u8) !void {
    try i18n.err(messages.unknown_command, .{raw});
}
