// apps/web/eslint.config.mjs
import js from '@eslint/js'
import globals from 'globals'
import tsParser from '@typescript-eslint/parser'
import tsPlugin from '@typescript-eslint/eslint-plugin'
import nextPlugin from '@next/eslint-plugin-next'

export default [
  // Ignore build output & deps
  {
    ignores: ['.next/**', 'node_modules/**', 'dist/**', 'coverage/**']
  },

  // Main rules for JS/TS/React/Next
  {
    files: ['**/*.{js,jsx,ts,tsx}'],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module'
        // If you later want type-aware rules, add:
        // project: ['./tsconfig.json']
      },
      globals: {
        ...globals.browser,
        ...globals.node
      }
    },
    plugins: {
      '@typescript-eslint': tsPlugin,
      '@next/next': nextPlugin
    },
    rules: {
      // Base JS recommendations
      ...js.configs.recommended.rules,

      // TypeScript recommendations (no type-aware rules yet)
      ...tsPlugin.configs.recommended.rules,

      // Next.js Core Web Vitals (flat-compatible)
      ...nextPlugin.configs['core-web-vitals'].rules
    }
  }
]
