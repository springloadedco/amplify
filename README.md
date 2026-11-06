# Amplify - It's orbin' time!

Amplify helps your [AmpCode](https://ampcode.com) orbs run your Laravel apps well, with fewer setup quirks.

Every new Laravel project on Amp needs the same setup: an orb setup script that installs PHP and
dependencies, services and a portal that serve the app over HTTPS, Laravel Boost wired to Amp, maybe the
Laravel Cloud or Forge CLI, and a few global Composer tools. Amplify aims to make that setup as quick and easy as possible.

## Install

#### For you

Paste this into any Amp thread, or tell Puck:

```text
Add the Amplify plugin from https://github.com/springloadedco/amplify to my personal plugins, then push it
```

Amp copies the plugin into your [personal plugins](https://ampcode.com/docs/customize/plugins), so it
loads in every new thread, on your machine and in orbs. Send the same message again to update.

Then open a Laravel app in Amp and ask: **"Set up orbs for this app."**

#### For a team workspace

A workspace admin can install it for everyone in the workspace:

```text
Add the Amplify plugin from https://github.com/springloadedco/amplify to our workspace plugins, then push it
```

Amplify is a [directory plugin](https://ampcode.com/docs/customize/plugins): an `amplify/` folder
with this repository's `index.ts`, `skills/`, and `LICENSE`. To keep it with one project instead,
put that folder in the project's `.amp/plugins/`.

## What it does

**`amplify:laravel-orb-setup` skill.** Ask Amp to "set up orbs for this Laravel app". The skill:

- writes `.agents/setup`, which installs PHP (8.4 by default, from packages.sury.org) with the
  common extensions, Composer, global Composer packages (`laravel/installer`,
  `laravel/cloud-cli`), Composer and JS dependencies, `.env` and `APP_KEY`, the database from
  the app's chosen database (SQLite, or MySQL, MariaDB, or PostgreSQL at a chosen version, under
  systemd), Redis when `.env` uses it,
  migrations, Mailpit, and a production asset build. It reads the project at run time and is safe
  to rerun.
- writes `.agents/resume`, which restarts those databases whenever an orb wakes and points the
  Forge CLI at your organization and server.
- writes `.amp/services.yaml`, the orb's `composer run dev`: `php artisan serve`, the Vite dev
  server with hot reload, `queue`, Reverb, and Mailpit (with its own portal, catching mail from
  the app and queue). The portal description says how to sign in when seeders create a user.
- serves the app, Vite's HMR websocket, and Reverb on one HTTPS portal through a small
  same-origin proxy, using the app's own `vite.config.js` and `echo.js` unchanged. Tested with
  a plain Laravel 13 app and the React, Vue, Svelte, and Livewire starter kits (Vite+, Inertia SSR,
  Livewire and Flux, Fortify auth).
- makes Laravel generate `https://` URLs behind the portal without touching the app's code: a
  PHP prepend file loaded only by the orb's `app` service marks portal requests as HTTPS, so no
  `trustProxies()` change to `bootstrap/app.php` is needed.
- keeps [Laravel Boost](https://github.com/laravel/boost) to a single source of truth. Team
  guidelines and skills live in `.ai/guidelines` and `.ai/skills`; Boost's per-agent copies
  (`AGENTS.md`, `CLAUDE.md`, `.agents/skills`, `.claude/skills`, MCP config, `boost.json`) are
  gitignored, as in Laravel's starter kits, and `.agents/setup` regenerates them for Amp with
  `boost:install` in every orb. Existing repositories have their hand-written content moved into
  `.ai/` and the generated copies untracked. Teams that keep a hand-written `CLAUDE.md` keep it:
  Boost's output goes to a gitignored `.ai/boost.md` that `CLAUDE.md` imports.
- asks what database production runs, sets orbs up with the same one, and recommends running the
  tests on it too instead of SQLite.

**Laravel context in every thread.** On a thread's first prompt in a Laravel repository, Amplify
tells the agent how to start the app's services, to use Boost's MCP tools, and, when the repository
has no `.agents/setup` yet, to use the skill above instead of Amp's generic orb setup.

## Configuration

`.agents/setup` reads these project environment variables (Amp project settings → Secrets & Env
Vars):

| Variable | Default | Purpose |
| --- | --- | --- |
| `AMPLIFY_PHP_VERSION` | `.php-version`, else `8.4` | PHP version to install |
| `AMPLIFY_PHP_EXTENSIONS` | none | Extra `php<version>-*` packages, e.g. `imagick swoole` |
| `AMPLIFY_COMPOSER_GLOBAL_PACKAGES` | `laravel/installer laravel/cloud-cli laravel/forge-cli` | Global Composer packages; empty to skip |
| `AMPLIFY_DATABASE` | chosen during setup, else `DB_CONNECTION` | `sqlite`, `mysql`, `mariadb`, or `pgsql` |
| `AMPLIFY_DATABASE_VERSION` | chosen during setup, else MySQL 8.4 / PostgreSQL 17 / MariaDB 10.11 | Database server version |
| `AMPLIFY_FRESH_SEED` | chosen during setup, else `1` | `1` runs `migrate:fresh --seed` in setup, `0` only `migrate` |

The first time it sets a project up, the skill asks, with Amp's option picker, which database
production runs (MySQL, MariaDB, PostgreSQL, or SQLite, and which version) and whether new orbs
should start from a freshly seeded database, and records both answers in `.agents/setup`. Local
service ports live in `.amp/orb.env`; change one there if it clashes with something the app
already runs.

Amplify supports Laravel 11 and newer. In a repository that already runs in Amp, the skill merges
its files with the existing `.agents/setup` and `.amp/services.yaml` instead of replacing them.
After the change lands, teammates run `php artisan boost:install` once in their local checkout,
because Boost's generated files are no longer committed. Threads whose orbs started before the
change keep their old environment; start a new thread to pick it up.

The Laravel Cloud CLI authenticates from `LARAVEL_CLOUD_TOKEN`. Store a
[Cloud API token](https://cloud.laravel.com/docs/api/authentication#create-an-api-token) as an
Amp secret with that name.

The Laravel Forge CLI authenticates from `FORGE_API_TOKEN`; store a Forge API token as an Amp
secret with that name. Forge also needs a current organization and server, which it keeps only in
its config file, so set `FORGE_ORGANIZATION` (organization slug) and `FORGE_SERVER` (server ID) as
Amp environment variables and `.agents/resume` writes them there whenever an orb wakes.

## License

MIT. See [LICENSE](LICENSE).
