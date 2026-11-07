---
name: laravel-orb-setup
description: Makes a Laravel repository ready for Amp orbs — PHP, Composer, global Composer tools (Laravel installer, Laravel Cloud CLI), databases, Mailpit, Vite hot reload and Reverb behind the portal, .agents/setup and resume, .amp/services.yaml with an HTTPS portal, and Laravel Boost wired to Amp. Use instead of the generic orb-setup skill whenever the repository is a Laravel app, or when asked to set up Boost or the Cloud CLI for Amp.
---

# Laravel Orb Setup

Prepare a Laravel repository so every new Amp orb starts with PHP, dependencies, a migrated
database, built assets, and Laravel Boost ready, and so the app runs behind an Amp portal.

The templates next to this file are the source of truth. Copy them; adjust only what the
project needs, and keep those adjustments small so later Amplify updates are easy to diff in.

- [templates/setup](templates/setup) — the `.agents/setup` script. It reads the project at run
  time: PHP version, JavaScript package manager, `DB_CONNECTION`, Redis usage. It also installs
  Mailpit.
- [templates/resume](templates/resume) — the `.agents/resume` script. It starts the databases
  setup installed whenever an orb wakes, and points the Forge CLI at an organization and server.
- [templates/services.yaml](templates/services.yaml) — `.amp/services.yaml`, the orb's
  `composer run dev`: `web` (the portal), `app` (`php artisan serve`), `vite` (dev server with
  hot reload), `queue`, `reverb`, and `mail` (Mailpit).
- [templates/php/](templates/php/) — `.amp/php/`, a PHP prepend file the `app` service loads so
  portal requests count as HTTPS without app changes.
- [templates/orb.env](templates/orb.env) — `.amp/orb.env`, the local ports and mail/Reverb
  settings every service loads. Ports are set only here.
- [templates/orb-proxy.mjs](templates/orb-proxy.mjs) — `.amp/orb-proxy.mjs`, the same-origin
  proxy behind the `web` portal.
- [templates/gitignore](templates/gitignore) — entries that commit Amplify's files.
- [boost-single-source.md](boost-single-source.md) — instructions for the optional follow-up
  thread that makes `.ai/` the single source of Boost's guidelines and skills.
- [templates/vite.config.mjs](templates/vite.config.mjs) — `.amp/vite.config.mjs`, which runs the
  app's own `vite.config.js` behind the portal with HMR.

## Steps

Ask every setup question in this skill with the `ask_user_choice` option picker, never as
freeform text in your reply: one call per question, with your recommended option first and marked
"(recommended)", and `allowOther` on so the user can type something else. Gather what you need
first, then ask questions that do not depend on each other in parallel, in the same response. If
`ask_user_choice` is not available, ask in text with the same numbered options.

## Changes to the app

Orb setup writes only Amplify's own files: `.agents/setup`, `.agents/resume`, `.amp/`, and the
Amplify entries in `.gitignore`. It never changes the application: no `composer require` or
upgrades, and no edits to `bootstrap/`, `config/`, `phpunit.xml`, `AGENTS.md`, `CLAUDE.md`, or
committed skills. When the steps below find an app change worth making, ask about it with the
picker (recommended option first, "Not now" last). After setup works, start one new thread with
`create_thread` that makes all the approved changes, so they land as their own reviewable
change; tell it the repository, the branch, and what each change is for, and point it at
[boost-single-source.md](boost-single-source.md) when that one is approved. Link the thread in
your report.

1. Confirm this is a Laravel 11 or newer app: `artisan` exists, `composer.json` requires
   `laravel/framework`, and `php artisan --version` reports 11 or higher. Amplify relies on
   Laravel 11's `bootstrap/app.php` middleware configuration and `/up` health route. For older
   apps, stop and tell the user to upgrade first or use the generic orb setup.

   Then choose the database with the user. Orbs should run what production runs. Read
   `DB_CONNECTION` in `.env.example`, `config/database.php`, CI workflows (`.github/workflows/*`,
   service containers and their image versions), `docker-compose.yml` or Sail, deploy config
   (`cloud.yaml`, Forge or Vapor files), and any existing `.agents/setup`. Present what you found
   and ask the user which database and version production uses, with your best guess first:
   SQLite, MySQL (8.4 or 8.0), MariaDB (a version or Debian's 10.11), or PostgreSQL (13-18). Never
   swap one engine for another on your own, such as MariaDB for MySQL. Record the answer as the
   defaults near the top of `.agents/setup`, e.g. `database=${AMPLIFY_DATABASE:-mysql}` and
   `database_version=${AMPLIFY_DATABASE_VERSION:-8.4}`, so every orb uses it. Setup points the
   orb's `.env` at that local server.

   Then check what the tests run on: `DB_CONNECTION` and `DB_DATABASE` in `phpunit.xml`, and
   CI. If tests use a different engine than production, usually SQLite `:memory:` while
   production runs MySQL or PostgreSQL, recommend running them on the production engine too:
   SQLite accepts queries, column types, and constraints that MySQL and PostgreSQL reject, so
   those bugs first show up in production. Setup already creates a `testing` database on the
   local server, so the change is `DB_CONNECTION` set to the production engine and
   `DB_DATABASE` set to `testing` in `phpunit.xml` (and the same in CI). That is an app change
   for the follow-up thread (see Changes to the app); mention that tests get somewhat slower.

   Then ask whether every new orb should start from a fresh, seeded database. Recommend yes when
   `database/seeders/DatabaseSeeder.php` creates users or data the app needs, and say which
   (e.g. "creates test@example.com"). With yes, setup runs `php artisan migrate:fresh --seed`;
   with no, only `php artisan migrate`. Record it as the default `fresh_seed=${AMPLIFY_FRESH_SEED:-1}`
   (or `:-0`) near the top of `.agents/setup`. Seeding runs only in setup, so an orb that wakes
   keeps its data; rerunning setup with `1` wipes the orb's local database. If the seeders fail
   on a fresh database, fix or report that before recommending yes.

2. Write `.agents/setup` from the template and `chmod +x` it. If the repository already has one,
   merge: keep project-specific steps the template lacks and replace the parts it covers.
   Setup picks PHP from Composer: `config.platform.php` if set, otherwise the newest version
   that `composer.json` and every package in `composer.lock` allow. Do not add a `.php-version`.
   Keep the `database`, `database_version`, and `fresh_seed` values chosen in step 1.
   Write `.agents/resume` from its template and `chmod +x` it. It starts the databases and sets
   the Forge CLI's organization and server.
   Merge [templates/gitignore](templates/gitignore) into `.gitignore`. Replace directory entries
   such as `/.agents` or `/.amp` (the starter kits have them) with the template's `/*` form;
   otherwise Git ignores `.agents/setup` and the other Amplify files. Check
   `git ls-files .agents .amp` lists the Amplify files once they are committed.

3. Copy `orb.env`, `orb-proxy.mjs`, `vite.config.mjs`, and `php/` into `.amp/`. Do not edit the app's
   `vite.config.js`; see How the portal works below. Write `.amp/services.yaml` from the
   template. If the repository already has one, merge instead of overwriting:
   - Keep every service the template does not cover, such as Horizon, an SSR server, a second
     portal, or a tunnel, along with its portal titles and descriptions.
   - Replace services the template covers: the one running `php artisan serve` becomes `app`
     behind `web`, a `vite` or `npm run build --watch` service becomes `vite`, and existing
     queue, Reverb, and Mailpit services become `queue`, `reverb`, and `mail`. Carry over their
     project-specific flags and `env` entries.
   - Move a hand-written proxy's routes into `.amp/orb-proxy.mjs` instead of keeping two proxies.
   - If a kept service listens on a port the template uses, change that port in `.amp/orb.env`,
     not the kept service.
   - Remove `.env` workarounds from earlier setups that the services now handle, such as a portal
     URL in `APP_URL` or `ASSET_URL`, and setup steps that replace the Vite dev server with
     `npm run build`.

   Then trim `.amp/services.yaml`:
   - Drop `vite` when the app has no `package.json` or no Vite.
     The `vite` service runs the app's own `dev` script with `--config .amp/vite.config.mjs`
     appended, which works for `vite` and for Vite+'s `vp dev` (the starter kits). If the `dev`
     script runs something else first, call Vite directly instead.
   - Drop `reverb` unless `composer.json` requires `laravel/reverb`.
   - Ports: services listen on the local ports in `.amp/orb.env` (8000, 5173, 8080, 1025 by
     default). Change one there if it clashes with something else in the orb; nothing else
     needs to change. Only `web` and `mail` use Amp's `$PORT`, because they have portals.
   - Drop `queue` when the app has no queued jobs and `QUEUE_CONNECTION` is `sync`.
   - Add services the project registers for `composer run dev` (check
     `php artisan tinker --execute 'echo json_encode(Illuminate\\Foundation\\DevCommands::commands());'`
     or the `dev` script in `composer.json`), such as Horizon or an SSR server. Skip Pail; the
     agent reads logs with `amp orb service logs <name>` and Boost's `read-log-entries`.
   - Tell people how to sign in. If seeders create a known user, give the `web` portal a
     `title` and a `description` with those credentials, e.g. `Sign in as test@example.com /
     password.` If the app needs a seeded user and setup does not seed, say how to create one.
   - Amp reads `${...}` inside a `command` as a service reference such as
     `${services.web.publicURL}`, so never use shell parameter expansion there; use `$VAR` and
     `sed` instead.

4. Copy `templates/php/` to `.amp/php/`. It makes requests from the HTTPS portal count as HTTPS
   inside the `app` service only, so Laravel generates `https://` URLs and validates signed URLs
   with no change to the app's code. Do not add `trustProxies()` to `bootstrap/app.php` or a
   `TRUSTED_PROXIES` entry to `.env.example` for the portal. If an earlier setup added
   `$middleware->trustProxies(at: env('TRUSTED_PROXIES'))` only for Amp, offer its removal (and
   the `TRUSTED_PROXIES` lines) for the follow-up thread; any `trustProxies` call the app has for
   production stays.

5. Laravel Boost. Read the installed version from `composer.lock` and the latest from
   `composer outdated laravel/boost --direct --format=json` (or
   `https://repo.packagist.org/p2/laravel/boost.json`). Then ask, each with the picker:
   - If Boost is missing or older than the latest release: "Boost is <installed>, the latest is
     <latest>. Upgrade it in a separate thread?" Upgrading means `composer require laravel/boost
     --dev` (or `composer update laravel/boost -W`), `php artisan boost:update`, and the test
     suite, all in the follow-up thread.
   - If the repository commits Boost's generated files (`git ls-files` on the paths from
     [Boost's output paths](boost-single-source.md#boosts-output-paths)), say how many duplicate skill and
     guideline copies that is, and ask whether the follow-up thread should make `.ai/` their
     single source ([boost-single-source.md](boost-single-source.md)). It also covers teams that
     keep a hand-written `CLAUDE.md`.
   - "Run `boost:install` in every orb?" With yes, setup adds `amp` to `boost.json` and runs
     `php artisan boost:install --no-interaction`, so each orb has Boost's guidelines, skills,
     and MCP server for Amp. Recommend yes when Boost's generated files are gitignored, as in
     the starter kits. When they are committed, recommend no unless the single-source change is
     also approved, because regenerating them changes committed files in every orb. Record the
     answer as `boost_install=${AMPLIFY_BOOST_INSTALL:-1}` (or `:-0`) near the top of
     `.agents/setup`.

6. Run `.agents/setup` and fix every failure until it exits 0. Run it a second time to prove it
   is idempotent. The log is useful to the user: report the total time.

7. Run `amp orb services ensure`. Confirm `web` responds, and open the portal URL with
   agent-browser to screenshot the home page. Check one generated URL is `https://`. If the app
   sends mail, trigger one email and confirm it appears in the Mailpit portal. Confirm hot reload:
   with the page open in agent-browser, append a visible CSS rule and check it applies without
   a reload (the `vite` log shows `hmr update`). If the app uses Reverb, check
   `Echo.connector.pusher.connection.state === 'connected'` and that a broadcast arrives. For an
   Inertia app with SSR enabled, check the HTML from `curl <portal>/` contains
   `data-server-rendered="true"`.

8. Check that setup changed nothing in the app: in a fresh clone (clone the repository to a
   temporary directory, copy `.env` and the new Amplify files, run `.agents/setup` there),
   `git status --porcelain` lists only the Amplify files. With `boost_install=1`, also check
   `amp mcp list` shows `laravel-boost` under the workspace settings and `AGENTS.md` contains
   the text of each `.ai/guidelines` file.

9. Laravel Cloud and Forge CLIs: setup installs `cloud` and `forge` globally. Both read their
   API token from the environment, so ask the user which they deploy with and tell them which
   Amp secrets to store (personal scope, or project scope for a shared deploy token). Never ask
   them to paste a token into the thread.
   - Laravel Cloud: `LARAVEL_CLOUD_TOKEN`.
   - Laravel Forge: `FORGE_API_TOKEN`, plus `FORGE_ORGANIZATION` (organization slug) and
     `FORGE_SERVER` (server ID) as environment variables. The Forge CLI keeps the current
     organization and server only in `~/.laravel-forge/config.json`, so `.agents/resume` writes
     them there on every wake; without them every Forge command stops with "You have not
     selected an organization". Commands that SSH into the server (`forge ssh`, `tinker`,
     `*:logs`) also need an SSH key on the server, which this setup does not create.
   - In an existing orb, run `amp orb restart-processes` to pick up new secrets.

## How the portal works

A page on one portal cannot reach another portal's hostname, so the Vite dev server, its HMR
websocket, and Reverb all share the app's origin. The `web` service runs `orb-proxy.mjs`:
`/__vite/*` (HTTP and websocket) goes to Vite, other websocket upgrades go to Reverb, and
everything else goes to `app` (`php artisan serve`).

`.amp/vite.config.mjs` loads the app's `vite.config.*` unchanged and adds `base: '/__vite/'`,
the portal origin, and HMR over `wss` on port 443. laravel-vite-plugin writes that origin to
`public/hot`, so `@vite` tags load from the portal and edits hot-reload in the browser: CSS and
JS through HMR, Blade and routes through a full reload. It also points Echo at the portal host
on port 443, so the stock `resources/js/echo.js` works. The app and queue reach Reverb directly
at `127.0.0.1:8080`. If the app's Vite config sets `base` or `server` options, check they still
merge sensibly.

Inertia SSR keeps working in dev: Inertia posts to `<public/hot>/__inertia_ssr`, so the wrapper
maps `/__vite/__inertia_ssr` back to Vite's `/__inertia_ssr`. `INERTIA_SSR_HOT_URL` cannot do
this, because the starter kits' published `config/inertia.php` replaces the whole `ssr` array.
Right after the `vite` service starts, Inertia logs `SSR skipped, module graph is still warming
up` and serves client-rendered pages; the first start after setup can take a minute while Vite
optimizes dependencies. Wait for `Inertia SSR module graph warmed up` in `amp orb service logs
vite` before judging SSR.

If an app's assets break under Vite, stop the `vite` service; `public/hot` is removed and
Laravel serves the `public/build` that setup built.

## Report

Tell the user what changed and what remains:

- New orbs use `.agents/setup` only after these files are committed and pushed to the default
  branch. An existing project snapshot keeps the old setup for up to 72 hours unless deleted:
  `amp projects snapshots delete <project>`.
- Global Composer packages default to `laravel/installer laravel/cloud-cli laravel/forge-cli`. Override them with
  the `AMPLIFY_COMPOSER_GLOBAL_PACKAGES` project environment variable, PHP with
  `AMPLIFY_PHP_VERSION`, and add PHP extensions with `AMPLIFY_PHP_EXTENSIONS`.
- Mail sent from the `web` and `queue` services goes to Mailpit; its portal is in the Portal tab.
- Which app changes you offered, which were approved, and the link to the follow-up thread
  making them. Setup itself changed only Amplify's files.
- Show the portal screenshot.
