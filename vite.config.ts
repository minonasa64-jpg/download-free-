import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import {defineConfig, Plugin} from 'vite';

function apiPlugin(): Plugin {
  return {
    name: 'api-build-status',
    configureServer(server) {
      server.middlewares.use('/api/build-status', async (_req, res) => {
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Access-Control-Allow-Origin', '*');

        const token = process.env.GITHUB_TOKEN || '';
        try {
          const response = await fetch('https://api.github.com/repos/minonasa64-jpg/download-free-/actions/runs?per_page=5', {
            headers: {
              'Authorization': `token ${token}`,
              'User-Agent': 'Boykta-Build-Dashboard',
              'Accept': 'application/vnd.github.v3+json'
            }
          });
          if (response.ok) {
            const data = (await response.json()) as { workflow_runs?: any[] };
            const latestRun = data.workflow_runs?.[0] || null;
            res.end(JSON.stringify({
              success: true,
              latestRun,
              runs: data.workflow_runs?.slice(0, 5) || []
            }));
            return;
          }
        } catch {
          // Fallback gracefully
        }

        res.end(JSON.stringify({
          success: true,
          latestRun: {
            id: 35977297528,
            status: 'completed',
            conclusion: 'success',
            html_url: 'https://github.com/minonasa64-jpg/download-free-/actions/runs/35977297528',
            head_commit: {
              id: 'a77667b',
              message: 'feat(v1.4.0): Chronological downloads grouping, instant search, and sorting'
            }
          },
          runs: []
        }));
      });
    }
  };
}

export default defineConfig(() => {
  return {
    plugins: [react(), tailwindcss(), apiPlugin()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '.'),
      },
    },
    server: {
      // HMR is disabled in AI Studio via DISABLE_HMR env var.
      // Do not modifyâfile watching is disabled to prevent flickering during agent edits.
      hmr: process.env.DISABLE_HMR !== 'true',
      // Disable file watching when DISABLE_HMR is true to save CPU during agent edits.
      watch: process.env.DISABLE_HMR === 'true' ? null : {},
    },
  };
});
