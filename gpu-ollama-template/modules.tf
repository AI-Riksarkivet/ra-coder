variable "claude_code_oauth_token" {
  description = "OAuth token passed to Claude Code via the CLAUDE_CODE_OAUTH_TOKEN env var. Generate one with `claude setup-token`."
  type        = string
  default     = ""
  sensitive   = true
}

module "claude-code" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/claude-code/coder"
  version                 = "5.2.0"
  agent_id                = coder_agent.main.id
  anthropic_api_key       = ""
  claude_binary_path      = "$HOME/.local/bin"
  claude_code_oauth_token = var.claude_code_oauth_token
  claude_code_version     = "latest"
  disable_autoupdater     = false
  enable_ai_gateway       = false
  icon                    = "/icon/claude.svg"
  install_claude_code     = true
  mcp                     = ""
  model                   = ""
  post_install_script     = null
  pre_install_script      = null
  workdir                 = null
}

module "vscode-web" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/vscode-web/coder"
  version                 = "1.5.0"
  agent_id                = coder_agent.main.id
  accept_license          = true
  auto_install_extensions = false
  commit_id               = ""
  disable_trust           = false
  extensions_dir          = ""
  folder                  = ""
  offline                 = false
  platform                = ""
  port                    = 13338
  subdomain               = false
  telemetry_level         = "error"
  use_cached              = false
  workspace               = ""
}

module "zed" {
  count      = data.coder_workspace.me.start_count
  source     = "registry.coder.com/coder/zed/coder"
  version    = "1.1.4"
  agent_id   = coder_agent.main.id
  agent_name = ""
  folder     = ""
  settings   = ""
}

module "git-config" {
  count                 = data.coder_workspace.me.start_count
  source                = "registry.coder.com/coder/git-config/coder"
  version               = "1.0.33"
  agent_id              = coder_agent.main.id
  allow_email_change    = false
  allow_username_change = true
}

module "dotfiles" {
  count                   = data.coder_workspace.me.start_count
  source                  = "registry.coder.com/coder/dotfiles/coder"
  version                 = "1.4.2"
  agent_id                = coder_agent.main.id
  default_dotfiles_branch = ""
  default_dotfiles_uri    = ""
  description             = "Enter a URL for a [dotfiles repository](https://dotfiles.github.io) to personalize your workspace. Use an SSH URL (e.g. `git@host:user/repo`) if your Git provider restricts HTTPS cloning."
  dotfiles_branch         = null
  dotfiles_uri            = null
  manual_update           = false
  post_clone_script       = null
  user                    = null
}

module "filebrowser" {
  count         = data.coder_workspace.me.start_count
  source        = "registry.coder.com/coder/filebrowser/coder"
  version       = "1.1.5"
  agent_id      = coder_agent.main.id
  agent_name    = "main"
  database_path = "filebrowser.db"
  folder        = "~"
  port          = 13339
  subdomain     = false
}

module "git-commit-signing" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-commit-signing/coder"
  version  = "1.0.32"
  agent_id = coder_agent.main.id
}