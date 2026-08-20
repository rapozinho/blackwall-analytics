/// <reference types="vite/client" />

/** Variáveis do build. `VITE_DEMO` liga o modo sem backend (`lib/demo.ts`);
 *  `VITE_REPO_URL` só alimenta o link da barra da demonstração. */
interface ImportMetaEnv {
  readonly VITE_DEMO?: string;
  readonly VITE_REPO_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
