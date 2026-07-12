/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ZIXFLOW_WRITE_KEY?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
