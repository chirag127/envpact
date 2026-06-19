#!/usr/bin/env node
/**
 * scripts/migrate-vault-v2-to-v3.mjs
 *
 * One-shot migration that flattens chirag127/envpact-secrets'
 * secrets.json from schema v2 to v3 per SHARED_SPEC.md §1.4.
 *
 * - shared.<KEY>: string → { value: string, _modified_at: ISO }
 * - projects.<name>.<KEY>:
 *     - string → { value: string, _modified_at: ISO }
 *     - object (per-env) → flattened by picking default → production →
 *                          first available value, then wrapped
 * - drops _default_env and any other underscore-prefixed metadata key
 * - bumps version 2 → 3, $schema → v3 URL, metadata.updated_at
 *
 * Idempotent: running on a v3 vault is a no-op except for an updated
 * _modified_at on entries that lacked one (defensive).
 *
 * Run from anywhere:
 *   node scripts/migrate-vault-v2-to-v3.mjs
 *
 * Reads/writes ~/.envpact/secrets/secrets.json. Doesn't commit or
 * push — caller is expected to review the diff first.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const HOME = process.env.USERPROFILE || process.env.HOME || homedir();
const VAULT = join(HOME, '.envpact', 'secrets', 'secrets.json');
const SCHEMA_V3 = 'https://envpact.oriz.in/schema/v3.json';

function pickFlatValue(envObj) {
  // Spec priority: default → production → first non-empty string value.
  if (typeof envObj.default === 'string' && envObj.default.length > 0) return envObj.default;
  if (typeof envObj.production === 'string' && envObj.production.length > 0) return envObj.production;
  for (const v of Object.values(envObj)) {
    if (typeof v === 'string' && v.length > 0) return v;
  }
  return '';
}

function migrate(vault) {
  const now = new Date().toISOString();
  const baseTs = vault.metadata?.updated_at || now;
  const out = {
    $schema: SCHEMA_V3,
    version: 3,
    shared: {},
    projects: {},
    metadata: {
      ...(vault.metadata || {}),
      updated_at: now,
    },
  };

  // shared
  for (const [k, v] of Object.entries(vault.shared || {})) {
    if (v && typeof v === 'object' && typeof v.value === 'string') {
      // Already v3-shaped; preserve, ensure _modified_at present.
      out.shared[k] = {
        value: v.value,
        _modified_at: v._modified_at || baseTs,
      };
    } else if (typeof v === 'string') {
      out.shared[k] = { value: v, _modified_at: baseTs };
    } else {
      console.error(`  ! shared.${k} has unsupported type ${typeof v}; skipping`);
    }
  }

  // projects
  for (const [pname, project] of Object.entries(vault.projects || {})) {
    out.projects[pname] = {};
    for (const [key, raw] of Object.entries(project)) {
      if (key.startsWith('_')) continue; // drop _default_env etc.
      if (raw && typeof raw === 'object' && typeof raw.value === 'string') {
        // Already v3-shaped.
        out.projects[pname][key] = {
          value: raw.value,
          _modified_at: raw._modified_at || baseTs,
        };
      } else if (typeof raw === 'string') {
        out.projects[pname][key] = { value: raw, _modified_at: baseTs };
      } else if (raw && typeof raw === 'object') {
        // v2 per-environment object — flatten.
        const picked = pickFlatValue(raw);
        if (!picked) {
          console.error(`  ! ${pname}.${key} has empty per-env object; skipping`);
          continue;
        }
        const sourceEnv = raw.default ? 'default' : raw.production ? 'production' : '<first>';
        console.warn(`  → ${pname}.${key}: flattened from per-env (picked "${sourceEnv}")`);
        out.projects[pname][key] = { value: picked, _modified_at: baseTs };
      } else {
        console.error(`  ! ${pname}.${key} unsupported type ${typeof raw}; skipping`);
      }
    }
  }

  return out;
}

function main() {
  console.log(`Reading ${VAULT}`);
  const raw = readFileSync(VAULT, 'utf8');
  const before = JSON.parse(raw);
  if (before.version === 3) {
    console.log('Vault is already v3; defensive _modified_at fill only.');
  } else {
    console.log(`Migrating v${before.version} → v3 …`);
  }

  const after = migrate(before);
  const out = JSON.stringify(after, null, 2) + '\n';
  writeFileSync(VAULT, out, 'utf8');

  console.log('');
  console.log(`Wrote ${VAULT}`);
  console.log(`Stats:`);
  console.log(`  shared:   ${Object.keys(after.shared).length} entries`);
  console.log(`  projects: ${Object.keys(after.projects).length}`);
  let totalKeys = 0;
  for (const p of Object.values(after.projects)) totalKeys += Object.keys(p).length;
  console.log(`  total project keys: ${totalKeys}`);
  console.log('');
  console.log('Review the diff with:');
  console.log(`  git -C ~/.envpact/secrets diff secrets.json | head`);
  console.log('Then commit + push:');
  console.log(`  git -C ~/.envpact/secrets add secrets.json`);
  console.log(`  git -C ~/.envpact/secrets commit -s -m "feat: migrate vault v2 → v3 (flat, per-key timestamps)"`);
  console.log(`  git -C ~/.envpact/secrets push`);
}

main();
