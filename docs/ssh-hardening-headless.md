# SSH Hardening & Headless Migration

## Summary

The Pi was previously administered locally — monitor and keyboard plugged in directly, switching HDMI input as needed. This work moved it to a fully headless setup: no desktop environment running at boot, administered exclusively over SSH using key-based authentication, with password authentication disabled entirely.

## Motivation

Two separate problems were being solved at once. First, the Pi was booting into a full desktop session (`graphical.target`) it never actually used, wasting an estimated 200–400 MB of RAM on hardware that doesn't have much to spare. Second, before removing the only fallback (a monitor plugged directly into the Pi), SSH needed to be the sole, reliable way in — which meant getting key-based auth working properly and removing password auth as an attack surface, rather than relying on a typed password as the only thing standing between "headless" and "locked out."

---

## Step 1 — Confirm SSH Access Before Removing the Fallback

Before touching the boot target, confirmed SSH was actually viable as the only way in going forward:

```bash
sudo systemctl status ssh
hostname -I
```

SSH was already installed, enabled, and running — it just hadn't been used yet, since the Pi had always been managed via direct monitor access up to this point.

---

## Step 2 — Set Up Key-Based Authentication

On the administering machine (a Windows PC), generated an ed25519 key pair:

```bash
ssh-keygen -t ed25519
```

This produces a private key (stays on the admin machine only, never copied anywhere) and a public key (`id_ed25519.pub`), which gets added to the Pi's authorized keys list:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "ssh-ed25519 AAAA...full-key-string... comment" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Gotchas

- An `authorized_keys` entry needs the **full line** — key type (`ssh-ed25519`), the base64 blob, and an optional comment — not just the base64 portion on its own. A bare blob missing the type prefix is silently ignored by sshd; it won't error, it just won't work.
- sshd enforces strict permission checks before it'll even consider a key: the home directory shouldn't be group/world-writable (`755` is fine), `.ssh` should be `700`, and `authorized_keys` should be `600`. Looser than that and sshd silently skips key auth entirely with no client-side error to explain why.
- An empty (0-byte) `authorized_keys` file is the simplest explanation when key auth keeps silently falling back to password — worth confirming with `wc -c ~/.ssh/authorized_keys` directly rather than assuming a previous `echo` actually wrote something.
- The private key only ever needs to exist on the connecting machine — the server never has it, never needs it, and testing `ssh user@server-ip` from the server itself doesn't validate anything about a remote machine's key, since the server has no private key of its own to offer.
- `ssh -v` on the client side is the fastest way to diagnose key issues definitively — it shows exactly which identity files were found, which key was offered, and whether the server accepted or rejected it, rather than guessing from a generic "Permission denied."
- On modern Debian/Raspberry Pi OS builds without rsyslog installed, `/var/log/auth.log` doesn't exist. Use `sudo journalctl -u ssh -f` instead to watch live authentication attempts.

---

## Step 3 — Disable Password Authentication

Once key-based login was confirmed working, password authentication was switched off entirely (covering both the standard password method and the PAM-based keyboard-interactive method, which can otherwise still allow password-style prompts even with the first one disabled):

```bash
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
sudo sshd -t                    # validate syntax before applying
sudo systemctl reload ssh       # reload, not restart — keeps existing sessions alive
sudo sshd -T | grep -iE "passwordauthentication|kbdinteractiveauthentication"
```

The last command checks the **actual effective configuration** (not just what's written in the file), which catches any other config snippet silently overriding the setting. Both should report `no`. A fresh connection attempt should log in via key with no password prompt offered at all.

---

## Step 4 — Switch to Headless Boot

With SSH solid and password-free, the boot target was changed to skip the desktop session entirely:

```bash
sudo systemctl set-default multi-user.target
sudo reboot
```

Verified after reboot:

```bash
systemctl get-default   # should report multi-user.target
free -h                 # compare against pre-change baseline
```

---

## Current State

The Pi now boots straight to a console login with no desktop environment running. Day-to-day administration is exclusively via SSH using ed25519 key-based authentication — password login is fully disabled at the server level.

If a monitor is ever plugged back in, it'll show a plain text console login prompt rather than a desktop, since `multi-user.target` still runs a getty on the local console — it isn't a black screen, just no GUI.

---

## Adding a New Device for SSH Access

Since password auth is off, a brand-new device can't add itself — its key has to be appended to `authorized_keys` by something that already has access (an existing authorized device, or direct console access on the Pi itself).

1. On the new device, generate its own key pair:
   ```bash
   ssh-keygen -t ed25519
   ```

2. Get its public key content:
   - macOS/Linux: `cat ~/.ssh/id_ed25519.pub`
   - Windows: `type %USERPROFILE%\.ssh\id_ed25519.pub`

3. From a device that's already authorized (or directly at the Pi), **append** the new public key as a new line — append, don't overwrite, since each device's key lives on its own line and they all coexist independently:
   ```bash
   echo "ssh-ed25519 AAAA...new-device-key... comment" >> ~/.ssh/authorized_keys
   ```

4. From the new device, test the connection — it should log in via key with no password prompt, exactly like the original setup.

No changes to `sshd_config` are needed for additional devices; it already accepts any valid key listed in `authorized_keys`, regardless of which machine generated it.
