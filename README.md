# homelab

## Day 1 — Provisioning and hardening an Ubuntu server

Set up a DigitalOcean droplet running Ubuntu 24.04 and hardened it.

### SSH keys instead of passwords
Generated an ed25519 key pair on my Mac. The public key goes on the
server, the private key never leaves my machine.

Why this is better than a password: Passwords are short enough to brute force and have to be sent to the server to be checked. With a key pair, the private key never leaves my machine, the server sends a challenge, my machine signs it, and the server verifies that signature against the public key. There's no secret in transit to intercept and nothing guessable to attack.													### Creating a non-root user
Made a user and added it to the sudo group instead of working as root.

What the sudo group does: The sudo group allows me to give my username Root permissions with a password barrier to confirm actions.
Why not just use root: Root has no restrictions to what can be altered which can be dangerous because any changes, big or small, can change the entire system. As well, as a normal user the permission system allows for double checks before making concrete decisions.

### Disabling root login and password auth
Edited /etc/ssh/sshd_config to set PermitRootLogin no and
PasswordAuthentication no.

I tested logging in as the new user in a second terminal BEFORE
disabling root, because: I tested logging in as the new user on a 2nd terminal to confirm that the user was able to login using the pass key and use privileges from the sudo group, had I closed the terminal without testing the log in I would have locked myself out.				
### Config files load in order
Found that /etc/ssh/sshd_config.d/ contained two files that also set
PasswordAuthentication. Later files override earlier ones.

Why this matters: This matters because if I edited an earlier file changing PasswordAuth while a file later down the line had it then it would override the changes I made, So I need to verify the behavior is correct to make sure its not being overridden.

### Firewall
Ran `ufw allow OpenSSH` before `ufw enable`.

Why that order: In that order because if I enable the firewall without allowing a point of entry for my machine I would have blocked any incoming connections into the system.