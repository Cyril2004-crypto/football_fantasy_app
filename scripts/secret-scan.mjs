import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const patterns = [
  { name: 'Bearer JWT token', regex: /Bearer\s+eyJ[\w.-]+/g },
  { name: 'Supabase service role key', regex: /SUPABASE_SERVICE_ROLE_KEY\s*=\s*(?!<)[^\s"'`]+/g },
  { name: 'Firebase web API key', regex: /FIREBASE_WEB_API_KEY\s*=\s*(?!<)[^\s"'`]+/g },
  { name: 'Ingestion shared secret', regex: /x-ingestion-secret\s*:\s*(?!<)[^\s"'`]+/gi },
  { name: 'Raw service role mention', regex: /SERVICE_ROLE_KEY\s*=\s*(?!<)[^\s"'`]+/g }
];

const ignoredPrefixes = [
  'build/',
  '.dart_tool/',
  'node_modules/',
  'backend/node_modules/',
  'android/app/build/',
  'ios/Pods/',
  '.git/',
  '.postman/'
];

const textExtensions = new Set([
  '.dart', '.js', '.mjs', '.json', '.yaml', '.yml', '.md', '.txt', '.ps1', '.sh',
  '.sql', '.mmd', '.rtf', '.html', '.css', '.ts', '.tsx'
]);

const files = execSync('git ls-files', { encoding: 'utf8' })
  .split(/\r?\n/)
  .filter(Boolean)
  .filter((file) => !ignoredPrefixes.some((prefix) => file.startsWith(prefix)))
  .filter((file) => textExtensions.has(path.extname(file).toLowerCase()));

const findings = [];

for (const file of files) {
  let content;
  try {
    content = readFileSync(file, 'utf8');
  } catch {
    continue;
  }

  const lines = content.split(/\r?\n/);
  lines.forEach((line, index) => {
    for (const pattern of patterns) {
      if (pattern.regex.test(line)) {
        findings.push({ file, line: index + 1, pattern: pattern.name, snippet: line.trim() });
      }
      pattern.regex.lastIndex = 0;
    }
  });
}

if (findings.length > 0) {
  console.error('Secret scan failed. Potential secrets found:');
  for (const finding of findings) {
    console.error(`${finding.file}:${finding.line} [${finding.pattern}] ${finding.snippet}`);
  }
  process.exit(1);
}

console.log(`Secret scan passed across ${files.length} tracked text files.`);