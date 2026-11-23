# SSH Attack Analysis

Five weeks of failed SSH login attempts against my internet-facing DigitalOcean droplet (Oct 18 – Nov 20, 2026), analyzed with Linux tools, Python, and pandas.

## Tools
Linux (grep, awk, sort, uniq), Python, pandas, regex, ip-api.com REST API

## How it works
1. Copied the rotated `/var/log/auth.log*` files from the droplet with `scp`. Raw logs are kept out of Git because they also contain my own IP.
2. `analyze.py` parses every "Invalid user" line, including the compressed `.gz` archives, into a pandas DataFrame with a regex.
3. Counts the top usernames, top IPs, unique IPs, and attempts per day.
4. Looks up the country and owning network of the top 10 IPs through the ip-api.com REST API.

## Findings
- **____ attempts** from **____ unique IPs** in five weeks, about 900 per day. The busiest day had ____.
- Most-tried usernames: `admin` (____), `user` (____), `ubuntu` (____). Bots target default accounts on servers, routers, and cloud images.
- The top attacker, `20.3.253.156` (Microsoft Azure, ____), made ____ attempts, about 9% of all traffic.
- One hosting provider, ____, controlled 3 of the top 10 IPs, with ____ attempts combined.
- Most top attackers ran from hosting providers. A few came from home and mobile ISPs, likely infected botnet devices.

## Why none got in
Password login and root login are disabled, so the server only accepts SSH keys. Guessing usernames and passwords can't work, no matter how many attempts are made.

## Next steps
- Load the logs into a SIEM (Splunk) to search and alert on them.
- Block repeat attackers automatically with fail2ban.
