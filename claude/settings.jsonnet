{
  permissions: {
    allow: [
      'Bash(ls:*)',
      'Bash(rg:*)',
      'Bash(grep:*)',
      'Bash(mkdir:*)',
      'Read(~/git/config/**)',
      'Glob(~/git/config/**)',
      'Read(~/.rbenv/**/*)',
      'Read(~/.cargo/registry/src/**/*)',
      'mcp__claude_ai_Linear',
      'mcp__aws-knowledge-mcp-server',
    ],
    deny: [],
  },
  local rubyHook(script) = 'env RBENV_VERSION= RBENV_DIR=/ ruby ~/git/config/claude/' + script,
  hooks: {
    UserPromptSubmit: [
      {
        _id: 'skill-reminder',
        hooks: [
          {
            type: 'command',
            command: rubyHook('skill-reminder.rb'),
          },
        ],
      },
    ],
    PreToolUse: [
      {
        _id: 'skill-reminder',
        matcher: 'Write|Edit|MultiEdit|Update',
        hooks: [
          {
            type: 'command',
            command: rubyHook('skill-reminder.rb'),
          },
        ],
      },
    ],
    PostToolUse: [
      {
        _id: 'ensure-newline',
        matcher: 'Write|Edit|MultiEdit|Update',
        hooks: [
          {
            type: 'command',
            command: 'env RBENV_VERSION= RBENV_DIR=/ ruby ~/git/config/claude/ensure-newline.rb',
          },
        ],
      },
      {
        _id: 'cargo-fmt',
        matcher: 'Write|Edit|MultiEdit|Update',
        hooks: [
          {
            type: 'command',
            command: 'env RBENV_VERSION= RBENV_DIR=/ ruby ~/git/config/claude/cargo-fmt.rb',
          },
        ],
      },
    ],
    Notification: [
      {
        _id: 'pushover',
        matcher: '*',
        hooks: [
          {
            type: 'command',
            command: 'envchain pushover env RBENV_VERSION= RBENV_DIR=/ ruby ~/git/config/claude/pushover.rb',
          },
        ],
      },
    ],
  },
  preferredNotifChannel: 'terminal_bell',
  skipAutoPermissionPrompt: true,
  extraKnownMarketplaces: {
    'sorah-marketplace': {
      source: {
        source: 'directory',
        path: '/home/sorah/git/config',
      },
    },
  },
  enabledPlugins: {
    'sorah-guides@sorah-marketplace': true,
    'sorah-spec@sorah-marketplace': true,
    'plugin-dev@claude-plugins-official': true,
    'rust-analyzer-lsp@claude-plugins-official': true,
    'ruby-lsp@claude-plugins-official': true,
    'typescript-lsp@claude-plugins-official': true,
  },
}
