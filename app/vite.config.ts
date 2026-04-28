import { paraglideVitePlugin } from '@inlang/paraglide-js';
import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { readFileSync } from 'node:fs';

const pkg = JSON.parse(readFileSync('package.json', 'utf-8'));

export default defineConfig({
	envDir: '../',
	define: {
		__APP_VERSION__: JSON.stringify(pkg.version)
	},
	plugins: [
		tailwindcss(),
		sveltekit(),
		paraglideVitePlugin({
			project: './project.inlang',
			outdir: './src/lib/paraglide',
			// `cookie` first: the user's saved language (cookie, hydrated from
			// users.locale by hooks.server.ts) wins over what the URL implies.
			// URL stays in the chain so direct links like /de/foo still work and
			// paraglide will redirect to the localized URL when they disagree.
			strategy: ['cookie', 'url', 'baseLocale']
		})
	]
});
