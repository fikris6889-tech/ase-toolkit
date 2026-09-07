# SAP ASE DBA Toolkit

A small, battle-tested collection of shell and SQL scripts for day-to-day
operation of **SAP ASE (Sybase Adaptive Server Enterprise)** instances
running on AWS — passwordless authentication setup, service status /
start / stop with production guardrails, and automated database +
transaction-log backups that sync to S3 and clean up after themselves.

Maintained by **Fikris Technologies**.

---

## What's in here

| Script | What it does |
|---|---|
| `scripts/ase_key.sh` | One-time setup: seeds the ASE credential store (`aseuserstore`) so every other script can connect via `isql -k DBA` without a plaintext password anywhere on disk. |
| `scripts/ase_status.sh` | Interactive menu to check status, start, or stop the ASE engine + Backup Server, with a confirmation gate before touching a Production SID. |
| `scripts/aws_ase_complete_data_backup.sh` | Cron/root entry point — drops into the SID's OS user and triggers a full database dump. |
| `scripts/aws_ase_log_backup.sh` | Cron/root entry point — drops into the SID's OS user and triggers a transaction-log dump. |
| `scripts/aws_ase_backupCleanup.sh` | Cron/root entry point — drops into the SID's OS user and triggers the S3 sync + local cleanup job. |
| `scripts/wrapper_complete_data_backup.sh` | Runs `sp_dumpdb` for `master` and the application database; installs the procedure first if it isn't already present. |
| `scripts/wrapper_log_backup.sh` | Runs `sp_dumptrans` for the application database; installs the procedure first if it isn't already present. |
| `scripts/wrapper_backupCleanup.sh` | Syncs the local data-dump and log-archive directories to S3, then deletes local copies older than a day. |
| `scripts/dumpdbcheck.sql` | Helper query — reports whether `sp_dumpdb` already exists in the instance. |
| `scripts/dumptranscheck.sql` | Helper query — reports whether `sp_dumptrans` already exists in the instance. |

Full parameter-by-parameter documentation is in
[`docs/SCRIPT_DOCUMENTATION.md`](docs/SCRIPT_DOCUMENTATION.md). The
story behind why this toolkit looks the way it does — including the
credential-hardening change described below — is in
[`docs/CASE_STUDY.md`](docs/CASE_STUDY.md).

## Prerequisites

- SAP ASE 16.0 installed under `/sybase/<SID>` (standard SAP-on-ASE layout)
- OS users following the `syb<sid>` naming convention (e.g. `sybp01` for SID `P01`)
- `root` access for the service-control script (`ase_status.sh`) and the cron entry points
- `saphostctrl` present under `/usr/sap/hostctrl/exe` (used for status checks)
- AWS CLI installed and configured with an IAM role/profile that can write to your backup bucket(s)
- A dedicated local staging path for backups (defaults assume `/dbbackup01/<SID>/backups/` and `/dbbackup01/<SID>/log_archives/`)

## Getting started

1. **Set up the credential store** (once per host, as `root`):
   ```bash
   ./scripts/ase_key.sh
   ```
   You'll be prompted for the ASE login's password — it is never written
   to disk or committed anywhere. See the Security notes below.

2. **Configure your S3 bucket names** before running any backup job:
   ```bash
   export S3_BUCKET_PREFIX="acme-ase-backup-enterprise"   # -> acme-ase-backup-enterprise-prod / -nonprod
   ```
   Set this in the environment of the user/cron job that runs the backup
   scripts (see Configuration below).

3. **Deploy the scripts on the ASE host**, matching the paths the
   wrappers expect:
   ```
   /usr/sap/ASE_SCRIPTS/wrapper/wrapper_complete_data_backup.sh
   /usr/sap/ASE_SCRIPTS/wrapper/wrapper_log_backup.sh
   /usr/sap/ASE_SCRIPTS/wrapper/wrapper_backupCleanup.sh
   /usr/sap/ASE_SCRIPTS/wrapper/dumpdbcheck.sql
   /usr/sap/ASE_SCRIPTS/wrapper/dumptranscheck.sql
   ```
   (Adjust the hardcoded paths inside the `aws_ase_*.sh` entry points if
   your standard differs.)

4. **Schedule the backups** — the three `aws_ase_*.sh` scripts are meant
   to be called by `root` via cron/systemd timer; they `su` into the SID
   user internally. A typical layout:
   ```cron
   0 2 * * * /usr/sap/ASE_SCRIPTS/aws_ase_complete_data_backup.sh
   0 * * * * /usr/sap/ASE_SCRIPTS/aws_ase_log_backup.sh
   30 2 * * * /usr/sap/ASE_SCRIPTS/aws_ase_backupCleanup.sh
   ```

5. **Day-to-day operations** — use `ase_status.sh` (as `root`) to check
   status or start/stop the instance interactively.

## Configuration

| Variable | Used by | Default | Purpose |
|---|---|---|---|
| `ASE_LOGIN` | `ase_key.sh` | `sapsa` | The ASE login seeded into the credential store. |
| `S3_BUCKET_PREFIX` | `wrapper_backupCleanup.sh` | `your-company-ase-backup-enterprise` (placeholder) | Backups are synced to `<prefix>-prod` or `<prefix>-nonprod` based on the SID's first letter. **You must set this** for your own environment. |

## Security notes

This is a public repository, so two things were changed from the
internal originals before publishing:

- **`ase_key.sh` no longer contains a hardcoded password.** The
  original internal version set the credential store key with the
  password written directly into the script. That's fine on a private,
  access-controlled host, but it's not something that should ever exist
  in a public (or even shared internal) git history. The script now
  prompts for the password interactively at runtime with `read -s`, so
  it's never echoed, written to disk, or committed anywhere. If you
  automate this further (e.g. run it non-interactively from a
  provisioning tool), pull the password from a proper secrets manager
  (AWS Secrets Manager, HashiCorp Vault, etc.) and pipe it in — don't
  put it back into the script as a literal.
- **Bucket names are placeholders.** `S3_BUCKET_PREFIX` defaults to
  `your-company-ase-backup-enterprise`, which is not a real bucket.
  Set it to your own organization's prefix before use.

See `docs/CASE_STUDY.md` for the fuller writeup.

## License

MIT — see [`LICENSE`](LICENSE).
