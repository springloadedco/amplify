import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import type { PluginAPI } from '@ampcode/plugin'

export const description =
	'Amplify: run Laravel on Amp well. Sets up orbs for Laravel apps (PHP, Composer, databases, services, HTTPS portal), installs Laravel Boost for Amp and the Laravel Cloud CLI, and points the agent at that setup in Laravel repositories.'

export default async function (amp: PluginAPI) {
	await amp.registerSkill({ path: 'skills/laravel-orb-setup' })

	const root = amp.system.workspaceRoot ? amp.helpers.filePathFromURI(amp.system.workspaceRoot) : null
	if (!root) return

	// Brief each thread once, on its first prompt in a Laravel app. Checked per prompt rather than
	// at load, so an app created mid-thread (e.g. with `laravel new`) is picked up.
	const briefedThreads = new Set<string>()

	amp.on('agent.start', async (event) => {
		if (briefedThreads.has(event.thread.id) || !isLaravelApp(root)) return {}
		briefedThreads.add(event.thread.id)
		return { message: { content: laravelContext(root) } }
	})
}

function isLaravelApp(root: string): boolean {
	if (!existsSync(join(root, 'artisan'))) return false
	try {
		const composer = JSON.parse(readFileSync(join(root, 'composer.json'), 'utf8'))
		return Boolean(composer.require?.['laravel/framework'])
	} catch {
		return false
	}
}

function laravelContext(root: string): string {
	const lines = ['This repository is a Laravel app.']

	if (!existsSync(join(root, '.amp/orb-proxy.mjs'))) {
		// Covers repos with no orb setup and repos with a hand-written one, where agents otherwise
		// fall back to a production build and hard-code the portal URL in .env.
		lines.push(
			'It does not have Amplify\'s orb setup yet. Before setting up orbs, running the app in a portal, or working around Vite, HMR, or http:// asset URLs behind a portal, load the amplify:laravel-orb-setup skill instead of the generic orb-setup skill. Do not replace the Vite dev server with `npm run build` or write a portal URL into .env.',
		)
	} else {
		lines.push(
			'`amp orb services ensure` is this orb\'s `composer run dev`: it starts the app, Vite with hot reload, the queue, and Mailpit, and prints the portal URLs. Frontend edits hot-reload in the portal; there is no need to run `npm run build`. Outgoing mail lands in the Mailpit portal. Restart a service with `amp orb service restart <name>` after changing .env or config.',
		)
	}
	if (existsSync(join(root, '.amp/settings.json')) && readFileSync(join(root, '.amp/settings.json'), 'utf8').includes('boost:mcp')) {
		lines.push(
			'Laravel Boost is installed: prefer its MCP tools (search-docs, database-schema, database-query, read-log-entries, last-error) over guessing. Its guidelines and skills have one source, .ai/guidelines and .ai/skills: edit those, then run `php artisan boost:update`. AGENTS.md, CLAUDE.md, and the skills folders under .agents, .claude, and other agent directories are generated copies; never edit or commit them.',
		)
	}

	return lines.join('\n')
}
