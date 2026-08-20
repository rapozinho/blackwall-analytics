import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// `VITE_BASE` = subcaminho onde o build vai ser servido. No GitHub Pages de
// projeto isso e "/<nome-do-repo>/"; servido pelo nginx do compose, e "/".
export default defineConfig({
  base: process.env.VITE_BASE ?? "/",
  plugins: [react()],
  server: {
    port: 5173,
    // dev: encaminha /api para o backend FastAPI
    proxy: { "/api": "http://localhost:8000" },
  },
});
