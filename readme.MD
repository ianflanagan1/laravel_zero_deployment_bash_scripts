# Laravel Zero-Deployment Bash Scripts

A collection of Bash script for setup and zero-downtime deployment of a Laravel project with Queue workers and Jenkins CI server. Includes shared boilerplate and unit tests

## Boilerplate
### Features
- Enable/disable strict mode:
  - fail on non-zero exit code (include within a pipe)
  - fail on reference to unset variable
- Parses any combination of short options (`-a`), grouped short options (`-abc`), long options (`--help`), options with trailing value joined by space or equals sign (`--option value` `--option=value` `-abc=zone=14,region=4`), and positional arguments
- Separate parsing of boilerplate options and script-specific options
- Cleanup after execution regardless of error/success

### Options
```
--help          Show usage information
-V, --version   Show version information
-v, --verbose   Enable verbose output
--debug         Enable debug output
--endopts       Stop reading options and arguments
--timeout <0>   Stop executing after a given number of seconds
```

### Improvements to consider implementing
- Boilerplate options:
  - -q, --quiet
  - --log <file>
  - --dry-run
- Allow empty string as an argument

## Directories
```
_buildignore        version-controlled, non-project files
  config            server config files: Nginx, Cron, Sudoers, Supervisor
  scripts
    lib             boilerplate code for all scripts
    local           scripts executed locally to affect local (dev) environment
    remote          scripts executed locally to affect remote (server) environments
    server          scripts executed on servers
    tests           unit test

_gitignore          non-version controlled files
  config            project-specific info referenced by scripts
    project         project name etc.
    environments    comma-separated production server SSH info
    jenkins         comma-separated CI server SSH info
```

## Scripts
#### remote/initialize-new-project.sh
Sets up user, group, and directories required for a new project on the server.

`Usage: initialize-new-project.sh [OPTIONS] <SERVER>`

#### remote/verify-project-setup.sh
Checks that the project setup on a server is satisfactory.

`Usage: verify-project-setup.sh [OPTIONS] <SERVER>`

#### remote/transfer.sh
Transfers files from the local environment to the server.

`Usage: transfer.sh [OPTIONS] <TYPE> <SERVER>`

`Types: Cron config, Sudoers config, Supervisor config, .env file, Nginx config, scripts (server/deploy_laravel_project), starting image (project specific)`

#### server/deploy_laravel_project
Triggered by Jenkins after new build files have been transferred to the server.

`Usage: deploy_laravel_project [OPTIONS] PROJECT_NAME ENVIRONMENT_NAME BUILD_NUMBER PHP_VERSION SUCCESSFUL_RELEASES_TO_KEEP`

#### local/pre-commit.sh
Standard local checks before `git commit`

`Usage: pre-commit.sh [OPTIONS]`

#### local/open-feature-branch.sh
Create a new feature branch (Gitflow workflow)

`Usage: open-feature-branch.sh  <FEATURE_BRANCH_NAME>`


## Setup

1. Search and replace "project-name" with genuine project name
2. Set up SSH for the dev user to access each server
3. Review and edit `_gitignore/config/` files
4. Populate `_gitignore/env-files/` with .env files for different environments e.g. `.env.production`, `.env.staging`, `.env.testing`
