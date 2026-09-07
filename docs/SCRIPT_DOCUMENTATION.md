# Script Documentation

Detailed reference for every script in this toolkit — what it does, who
should run it, what it expects to find on the system, and sample usage.

All scripts assume the standard SAP-on-ASE layout: ASE installed under
`/sybase/<SID>/ASE-16_0`, an OS user per SID following the `syb<sid>`
convention, and the SID discoverable from mounted filesystems
(`df -h | grep '/sybase/'`) or from the `$SYBASE` environment variable.

---

## `ase_key.sh`

**Run as:** `root`, once per host (or whenever the ASE login's password changes)

**Purpose:** Seeds the ASE credential store (`aseuserstore`) with a `DBA`
key so that every other script in this toolkit can authenticate with
`isql -k DBA` instead of a password on the command line.

**What it does:**
1. Confirms it's running as `root`.
2. Auto-detects the SID from the mounted `/sybase/<SID>` path.
3. Prompts interactively for the ASE login's password (`read -s`, not echoed).
4. Runs `aseuserstore set DBA '<host> 4901' <login> '<password>'` as the SID's OS user.
5. Lists the credential store (`aseuserstore list`) so you can confirm the key exists.
6. Runs a one-off test query (`select name,dbid from master..sysdatabases`) through the new key to prove it works, then deletes the temp SQL file.

**Configuration:**
- `ASE_LOGIN` (env var, default `sapsa`) — which ASE login to seed the key for.

**Usage:**
```bash
sudo ./ase_key.sh
# Enter the password for ASE login 'sapsa' on system P01:
# Password: ********
```

**Notes:** This script intentionally does not accept the password as a
command-line argument or hardcoded value — both would leave it visible
in shell history or `ps` output / source control respectively. See the
Security notes in the main README.

---

## `ase_status.sh`

**Run as:** `root`, interactively

**Purpose:** Menu-driven status/start/stop control for the ASE engine
and Backup Server, with an extra confirmation step when the detected SID
looks like a Production system (SID starting with `P`).

**What it does:**
1. Auto-detects the SID.
2. If the SID starts with `P`, asks for an explicit `Yes`/`No` confirmation before showing the operations menu at all.
3. Presents a menu:
   - **1 — Status:** calls `saphostctrl -function GetDatabaseStatus` and greps for `Status`.
   - **2 — Start:** runs `startserver` for both the ASE engine and its Backup Server.
   - **3 — Stop:** asks for a second `Yes`/`No` confirmation, then runs `stop.sql` via `isql -k DBA`.
   - **4 — Exit.**

**Usage:**
```bash
sudo ./ase_status.sh
```

**Dependencies:** `saphostctrl` under `/usr/sap/hostctrl/exe`; a
`stop.sql` script present at `/usr/sap/ASE_SCRIPTS/stop.sql` (not
included in this repo — write one for your environment, e.g. a clean
`shutdown` via `isql`); the credential store set up by `ase_key.sh`.

---

## `aws_ase_complete_data_backup.sh` / `aws_ase_log_backup.sh` / `aws_ase_backupCleanup.sh`

**Run as:** `root` (designed to be called from cron/systemd timers)

**Purpose:** Thin entry points. Each one auto-detects the SID, then
`su`s into the corresponding `syb<sid>` OS user and calls the matching
wrapper script under `/usr/sap/ASE_SCRIPTS/wrapper/`. Splitting the
root-level cron entry from the SID-user wrapper keeps the actual backup
logic running as the correct, least-privileged OS user.

| Entry point | Calls |
|---|---|
| `aws_ase_complete_data_backup.sh` | `wrapper/wrapper_complete_data_backup.sh` |
| `aws_ase_log_backup.sh` | `wrapper/wrapper_log_backup.sh` |
| `aws_ase_backupCleanup.sh` | `wrapper/wrapper_backupCleanup.sh` |

**Usage (cron, as root):**
```cron
0 2 * * * /usr/sap/ASE_SCRIPTS/aws_ase_complete_data_backup.sh >> /var/log/ase_backup.log 2>&1
0 * * * * /usr/sap/ASE_SCRIPTS/aws_ase_log_backup.sh >> /var/log/ase_backup.log 2>&1
30 2 * * * /usr/sap/ASE_SCRIPTS/aws_ase_backupCleanup.sh >> /var/log/ase_backup.log 2>&1
```

**Note:** these scripts hardcode the deployment path
`/usr/sap/ASE_SCRIPTS/wrapper/...`. If you deploy elsewhere, update the
path in each script accordingly.

---

## `wrapper_complete_data_backup.sh`

**Run as:** the SID's OS user (e.g. `sybp01`) — refuses to run as `root`

**Purpose:** Takes a full database dump of `master` and of the SID's
application database using SAP's `sp_dumpdb` procedure.

**What it does:**
1. Refuses to run if `$UID == 0` (must run as the `sidadm`-style user).
2. Reads the SID from `$SYBASE`.
3. Runs `docs/../scripts/dumpdbcheck.sql` (deployed as `wrapper/dumpdbcheck.sql`) to check whether `sp_dumpdb` already exists.
4. If missing, installs it from `/usr/sap/ASE_SCRIPTS/sp_dumpdb.sql` (not included — this is SAP's standard `sp_dumpdb`/`sp_dumptrans` installer script, available from SAP Note repositories for ASE-on-SAP).
5. Dumps `master`, then the SID's application database, via `saptools..sp_dumpdb`.

**Dependencies:** `dumpdbcheck.sql` deployed alongside it; `sp_dumpdb.sql` installer present if the procedure isn't already installed; the `DBA` credential store key from `ase_key.sh`.

---

## `wrapper_log_backup.sh`

**Run as:** the SID's OS user — refuses to run as `root`

**Purpose:** Takes a transaction-log dump of the SID's application
database using `sp_dumptrans`, installing the procedure first if needed
(mirrors `wrapper_complete_data_backup.sh` exactly, but for logs).

**Dependencies:** `dumptranscheck.sql`; `sp_dumptrans.sql` installer if needed; the `DBA` credential store key.

---

## `wrapper_backupCleanup.sh`

**Run as:** the SID's OS user

**Purpose:** Pushes local backup artifacts to S3 for durable, off-host
retention, then deletes the local copies so the backup filesystem
doesn't fill up.

**What it does:**
1. Reads the SID from `$SYBASE`.
2. Picks a bucket based on the SID's first letter: `<S3_BUCKET_PREFIX>-prod` if the SID starts with `P`, otherwise `<S3_BUCKET_PREFIX>-nonprod`.
3. `aws s3 sync`s `/dbbackup01/<SID>/backups/` and `/dbbackup01/<SID>/log_archives/` to that bucket, under `backup/<SID>/usr/sap/<SID>/SYS/global/syb/backup/ASE_<SID>/`.
4. Deletes local files in those two directories older than one day (`-mtime +0`) — only after the sync above has completed.

**Configuration:**
- `S3_BUCKET_PREFIX` (env var) — **required**; see README. There is no working default — the built-in fallback is a placeholder.

**Dependencies:** AWS CLI configured with write access to the target bucket(s); local backup files present under `/dbbackup01/<SID>/`.

---

## `dumpdbcheck.sql` / `dumptranscheck.sql`

**Run by:** `isql -k DBA -X -i <file>`, invoked from the wrapper scripts — not intended to be run standalone.

**Purpose:** Each runs `sp_help`, greps the output for the target
procedure name (`sp_dumpdb` / `sp_dumptrans`), and returns a count so
the calling wrapper can decide whether to install the procedure before
using it.
