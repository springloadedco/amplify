# Amplify - It's orbin' time!

Amplify helps your [AmpCode](https://ampcode.com) orbs run your Laravel apps well, with fewer setup quirks.

Every new Laravel project on Amp needs the same setup: an orb setup script that installs PHP and
dependencies, services and a portal that serve the app over HTTPS, Laravel Boost wired to Amp,
Laravel Cloud and Forge CLI's, and a few global Composer tools. 

Amplify removes a few paper cuts that you'll normally run into when getting Laravel running on your orb.

## What you get

- **One prompt to set up an orb.** Ask Amp to "Set up orbs for this app" and it writes `.agents/setup`, `.agents/resume`, and `.amp/services.yaml` for you.
- **An orb that's ready to work.** It installs PHP, Composer, and your dependencies, creates `.env` and `APP_KEY`, and runs your migrations and seeders.
- **The database you use in production.** SQLite, MySQL, MariaDB, or PostgreSQL at the version you pick, plus Redis if your app uses it.
- **`composer run dev`, in the orb.** You get the app, Vite with hot reload, a queue worker, Reverb, and Mailpit to catch outgoing mail.
- **One HTTPS portal that works.** The app, hot reload, and Reverb all run on one portal URL with correct `https://` links, and you don't have to change your app's code.
- **Laravel Boost and the Cloud and Forge CLIs set up for Amp.** Boost reads your guidelines from `.ai/`, and the CLIs sign in with your Amp secrets.
- **Laravel context in every thread.** Amp knows how to start your services and use Boost's tools from your first prompt.

Works with Laravel 11 and later. If you already have setup files, it adds to them instead of replacing them.

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
- wires [Laravel Boost](https://github.com/laravel/boost) to Amp: if you choose, every orb runs
  `boost:install` so Boost's guidelines, skills, and MCP server are ready.
- asks what database production runs and sets orbs up with the same one.
- never changes your app. Setup writes only `.agents/`, `.amp/`, and Amplify's `.gitignore`
  entries. Changes it recommends, such as upgrading Boost, making `.ai/` the single source of
  Boost's guidelines and skills instead of committing a copy per agent, or running tests on the
  production database instead of SQLite, are offered one by one and made in a separate thread
  you review.

**Laravel context in every thread.** On a thread's first prompt in a Laravel repository, Amplify
tells the agent how to start the app's services, to use Boost's MCP tools, and, when the repository
has no `.agents/setup` yet, to use the skill above instead of Amp's generic orb setup.

## Configuration

`.agents/setup` reads these project environment variables (Amp project settings → Secrets & Env
Vars):

| Variable | Default | Purpose |
| --- | --- | --- |
| `AMPLIFY_PHP_VERSION` | `config.platform.php`, else the newest PHP that `composer.json` and `composer.lock` allow | PHP version to install |
| `AMPLIFY_PHP_EXTENSIONS` | none | Extra `php<version>-*` packages, e.g. `imagick swoole` |
| `AMPLIFY_COMPOSER_GLOBAL_PACKAGES` | `laravel/installer laravel/cloud-cli laravel/forge-cli` | Global Composer packages; empty to skip |
| `AMPLIFY_DATABASE` | chosen during setup, else `DB_CONNECTION` | `sqlite`, `mysql`, `mariadb`, or `pgsql` |
| `AMPLIFY_DATABASE_VERSION` | chosen during setup, else MySQL 8.4 / PostgreSQL 17 / MariaDB 10.11 | Database server version |
| `AMPLIFY_FRESH_SEED` | chosen during setup, else `1` | `1` runs `migrate:fresh --seed` in setup, `0` only `migrate` |
| `AMPLIFY_BOOST_INSTALL` | chosen during setup, else `1` | `1` runs `boost:install` for Amp in setup, `0` skips it |

The first time it sets a project up, the skill asks, with Amp's option picker, which database
production runs (MySQL, MariaDB, PostgreSQL, or SQLite, and which version), whether new orbs
should start from a freshly seeded database, and whether they run `boost:install`, and records
the answers in `.agents/setup`. Local
service ports live in `.amp/orb.env`; change one there if it clashes with something the app
already runs.

Amplify supports Laravel 11 and newer. In a repository that already runs in Amp, the skill merges
its files with the existing `.agents/setup` and `.amp/services.yaml` instead of replacing them.
Threads whose orbs started before the
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
