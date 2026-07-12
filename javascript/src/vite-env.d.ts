/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ZIXFLOW_WRITE_KEY?: string
  readonly VITE_ZIXFLOW_SITE_ID?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
