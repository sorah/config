{
  permissions: {
    allow: [
      'Bash(ls:*)',
      'Bash(rg:*)',
      'Bash(grep:*)',
      'Bash(mkdir:*)',
      'Bash(sorah-agent-board:*)',
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
        _id: 'fmt',
        matcher: 'Write|Edit|MultiEdit|Update',
        hooks: [
          {
            type: 'command',
            command: 'env RBENV_VERSION= RBENV_DIR=/ ruby ~/git/config/claude/fmt.rb',
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
  } + std.foldl(
    function(acc, event) acc + {
      [event]+: [
        {
          _id: 'agent-board',
          hooks: [
            {
              type: 'command',
              // Errors go to a log so a broken working tree never interrupts live sessions.
              command: 'env RBENV_VERSION= RBENV_DIR=/ ruby --disable-gems ~/git/config/bin/sorah-agent-board hook 2>>"${XDG_STATE_HOME:-$HOME/.local/state}/sorah-agent-board/hook-errors.log" || true',
            },
          ],
        },
      ],
    },
    [
      'SessionStart',
      'UserPromptSubmit',
      'PreToolUse',
      'PostToolUse',
      'PostToolUseFailure',
      'PermissionRequest',
      'PermissionDenied',
      'Elicitation',
      'ElicitationResult',
      'Notification',
      'SubagentStart',
      'Stop',
      'StopFailure',
      'SessionEnd',
    ],
    {},
  ),
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
