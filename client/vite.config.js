import process from 'node:process';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig(({ command, mode }) => {
  // App.jsx falls back to http://localhost:3000/api/v1 when VITE_API_BASE_URL is
  // unset, so a production build without it ships a site where every API call
  // fails. Refuse to build instead. loadEnv reads the .env files and the process
  // environment (e.g. Vercel project variables) the same way Vite does.
  if (command === 'build' && mode === 'production' && !loadEnv(mode, process.cwd()).VITE_API_BASE_URL?.trim()) {
    throw new Error(
      'VITE_API_BASE_URL is not set. Production builds need the API base URL, e.g. https://api.hamme.app/api/v1',
    );
  }

  return {
    plugins: [react(), tailwindcss()],
    server: {
      host: '0.0.0.0',
      port: 5173,
      strictPort: true,
    },
  };
});
