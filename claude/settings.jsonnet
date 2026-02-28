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
  hooks: {
    PostToolUse: [
      {
        matcher: 'Write|Edit|MultiEdit|Update',
        hooks: [
          {
            type: 'command',
            command: 'env RBENV_VERSION= RBENV_DIR=/ ruby ~/git/config/claude/ensure-newline.rb',
          },
        ],
      },
    ],
    Notification: [
      {
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
}
