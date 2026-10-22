---
name: zepher-data-vault
description: Automate team data management, secure secret vaulting (.env encryption & passhash generation), and heavy asset distribution via blob storage (AWS S3, Cloudflare R2, Google Drive). Use when managing .env, secrets, seeds, datasets, documents, or binaries across AI agents and team members.
version: 1.0.0
trigger: When managing .env files, secrets, credentials, database seeds, large documents, datasets, or blob assets in a Zepher project.
---

# Zepher Data Vault & Asset Distribution Skill

This skill guides AI agents and developers in securing team secrets (like `.env`), generating cryptographic passhashes, and distributing heavy datasets and document bundles using Zepher Team Vault and Asset Hub with cloud blob storage (AWS S3, Cloudflare R2, Google Drive).

---

## 🎯 When to Use This Skill
- The user or agent needs to store, encrypt, or share `.env` or configuration secrets across teammates without leaking plaintext into Git.
- The user needs to generate a secure passphrase or passhash for AES-256-GCM envelope encryption.
- The user or agent needs to track and share heavy datasets, database seeds, machine learning weights, or large document folders (>25MB) without bloating the Git repository.
- The user wants to integrate cloud blob storage (S3, Cloudflare R2, Google Drive, or MinIO) with Zepher's content-addressable SHA-256 asset pointer lockfile (`assets.lock.yaml`).

---

## 🧠 Decision Heuristic: Vault vs. Asset Hub

Before executing commands, determine whether the target data is a **Secret** or a **Heavy Asset**:

```
                              Is the data sensitive / confidential?
                              (e.g., .env, API keys, private tokens,
                               confidential legal/audit documents)
                                         /            \
                                       YES            NO
                                       /                \
                       Use Zepher Team Vault      Is the file heavy (>25MB),
                       (zepher vault)             a dataset, or binary?
                       - Client-side AES-256-GCM         /             \
                       - Safe in Git as .enc           YES              NO
                                                       /                 \
                                              Use Zepher Asset Hub    Standard Git
                                              (zepher asset)          commit is fine
                                              - SHA-256 blob storage
                                              - Offload to S3/R2/GDrive
```

---

## 🔐 Part 1: Managing `.env` and Team Secrets (`zepher vault`)

Zepher Team Vault encrypts files into zero-knowledge **AES-256-GCM envelopes** using **PBKDF2 key derivation (100,000 iterations, SHA-256 salt)**.

### Step 1.1: Generate a Cryptographic Passhash / Passphrase
To ensure maximum entropy, generate a 32-byte cryptographic key rather than using a guessable password:

```bash
# Option A: OpenSSL (Recommended)
openssl rand -base64 32

# Option B: Node.js Crypto One-Liner
node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"

# Option C: /dev/urandom on Linux
tr -dc 'A-Za-z0-9!@#$%^&*()' </dev/urandom | head -c 32; echo
```

**Storing the Passphrase:**
- Store the generated passhash in a team password manager (e.g., 1Password, Bitwarden) or team secret store.
- For automation, export it in your shell environment or CI/CD runner:
  ```bash
  export ZEPHER_VAULT_KEY="<generated-passhash>"
  ```

### Step 1.2: Track the `.env` File
Register the secret with Zepher:
```bash
zepher vault track .env -t secret
# For environment-specific files:
zepher vault track .env.production -t secret
zepher vault track .env.staging -t secret
```
> **Automatic Git Shield:** Zepher immediately appends the tracked file path to `.gitignore` under `# Zepher Vault Protected Files (Do Not Commit Plaintext)` so unencrypted secrets can never be accidentally committed.

### Step 1.3: Seal (Encrypt) the Envelopes
```bash
zepher vault seal -p "$ZEPHER_VAULT_KEY"
```
**Artifacts created:**
- `.zepher/vault/_env.enc`: The AES-256-GCM ciphertext envelope containing the IV, salt, auth tag, and encrypted payload.
- `.zepher/vault-lock.yaml`: Lockfile recording the file path, SHA-256 hash, and seal timestamp.
- `.zepher/vault.yaml`: Configuration listing all tracked files and their asset types.

### Step 1.4: Verify and Commit to GitHub
```bash
# Verify status (should report [SEALED & IN SYNC])
zepher vault status

# Commit only the encrypted envelopes, config, and .gitignore
git add .gitignore .zepher/vault.yaml .zepher/vault-lock.yaml .zepher/vault/
git commit -m "chore(vault): seal .env in zero-knowledge vault"
git push origin main
```

### Step 1.5: Teammates or CI Unseal
When a teammate pulls the repository or CI starts a build:
```bash
git pull
zepher vault unseal -p "$ZEPHER_VAULT_KEY"
```
- **Smart 3-Way Reconciliation:** Zepher inspects existing local `.env` keys. If a developer has local development overrides (e.g. `PORT=3001` or `DEBUG=true`), Zepher merges team keys without clobbering local modifications.

---

## 📦 Part 2: Distributing Heavy Assets, Datasets & Documents (`zepher asset`)

Git is not designed to store massive binaries, large CSV/Parquet files, SQLite dumps, or PDF bundles. Zepher Asset Hub uses **content-addressable SHA-256 pointers** in `.zepher/assets.lock.yaml` so Git only tracks small pointer manifests while actual data is stashed in blob stores.

### Step 2.1: Package Folders (If applicable)
If you are sharing an entire directory of documents, images, or seed files:
```bash
# Archive the folder into a compressed bundle
tar -czf data-bundle.tar.gz data/
# or
zip -r documents.zip documents/
```

### Step 2.2: Track the Asset
```bash
zepher asset track data-bundle.tar.gz --tag "v1.0" --storage s3
```
- Zepher hashes the file using SHA-256.
- Automatically adds `data-bundle.tar.gz` to `.gitignore`.
- Updates `.zepher/assets.lock.yaml`:
  ```yaml
  assets:
    data-bundle.tar.gz:
      path: data-bundle.tar.gz
      sha256: 3c9b...a17f
      size: 154829312
      location: .zepher/assets/blobs/3c9ba17f8e21
      tag: v1.0
  ```

### Step 2.3: Stash into Local Blob Store
```bash
zepher asset stash data-bundle.tar.gz
```
Copies the file to `.zepher/assets/blobs/<sha256-prefix>`.

---

## ☁️ Part 3: Cloud Blob Storage Integrations (S3, Cloudflare R2, Google Drive)

To share the blob files across teammates without checking them into Git:

### Option A: AWS S3 or MinIO
1. **Upload Stashed Blobs:**
   ```bash
   aws s3 sync .zepher/assets/blobs/ s3://my-team-bucket/zepher-blobs/
   ```
2. **Teammates Restore Blobs and Rebuild Asset:**
   ```bash
   git pull
   # Download missing blobs from S3
   aws s3 sync s3://my-team-bucket/zepher-blobs/ .zepher/assets/blobs/
   # Pull and verify asset integrity
   zepher asset pull data-bundle.tar.gz
   tar -xzf data-bundle.tar.gz
   ```

### Option B: Cloudflare R2 (Zero-Egress Fee Alternative)
Cloudflare R2 uses the S3-compatible API:
1. **Upload:**
   ```bash
   aws s3 sync .zepher/assets/blobs/ s3://my-r2-bucket/zepher-blobs/ \
     --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com
   ```
2. **Download & Pull:**
   ```bash
   aws s3 sync s3://my-r2-bucket/zepher-blobs/ .zepher/assets/blobs/ \
     --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com
   zepher asset pull data-bundle.tar.gz
   ```

### Option C: Google Drive via `rclone`
`rclone` provides direct command-line synchronization with Google Drive:
1. **Configure rclone:**
   ```bash
   # Configure once (select Google Drive)
   rclone config
   ```
2. **Sync Blobs to Google Drive:**
   ```bash
   rclone sync .zepher/assets/blobs/ gdrive:zepher-assets/<project-name>/blobs/
   ```
3. **Teammates Download and Restore:**
   ```bash
   rclone sync gdrive:zepher-assets/<project-name>/blobs/ .zepher/assets/blobs/
   zepher asset pull data-bundle.tar.gz
   tar -xzf data-bundle.tar.gz
   ```

---

## 🤖 Agent Autonomous Action Checklist

When an agent is requested to secure `.env` or distribute data:

1. **Scan for plaintext leaks:**
   - Execute `git status` and verify `.env` or raw data files are **not** staged or tracked by git.
   - If tracked, run `git rm --cached <file>`.
2. **Execute Vault or Asset lifecycle:**
   - For secrets: `zepher vault track <file> -t secret` -> `zepher vault seal -p "$PASSPHRASE"` -> verify with `zepher vault status`.
   - For assets: `zepher asset track <file>` -> `zepher asset stash <file>`.
3. **Update Git with safe envelopes/pointers:**
   - `git add .gitignore .zepher/vault* .zepher/assets*`
   - `git commit -m "chore(zepher): update team vault and asset tracking"`
4. **Log instructions for teammates in session handoff:**
   - Mention the exact `zepher vault unseal` or `zepher asset pull` command in `.zepher/handoffs/` so the next agent or teammate knows how to restore the workspace.
