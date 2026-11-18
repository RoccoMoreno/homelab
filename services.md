Droplet — nginx
Installed nginx on my DigitalOcean droplet and served the default page over the public internet.

sudo apt install nginx (apt = Advanced Package Tool, Ubuntu's package manager — pulls dependencies 
automatically)
sudo systemctl status nginx → active (running), enabled (auto-starts on boot)
Page wouldn't load: ufw firewall from initial hardening only allowed OpenSSH (port 22). nginx serves 
on port 80.
sudo ufw allow "Nginx HTTP" opened port 80 → page loaded at http://<public-ip>
Lesson: installed ≠ running ≠ reachable. A service can be up and still blocked by the firewall
. HTTP is port 80, HTTPS is 443 (needs a TLS cert).

Droplet — custom nginx page
Replaced the default page with my own. nginx serves from /var/www/html; the default file 
is index.nginx-debian.html.

Found it: cd /var/www/html, cat confirmed it held the "Welcome to nginx!" HTML
sudo nano to edit (owned by root, needs sudo)
Wrote my own HTML, refreshed browser → live
Concept: document root — the folder a web server treats as the top of the site. Visiting the IP with 
no path makes nginx serve the index file from there.

Droplet — nginx in Docker
Installed Docker from official docs (GPG key + repo + docker-ce packages), confirmed with systemctl 
status docker.

sudo usermod -aG docker rocco to use Docker without sudo (takes effect after re-login)
docker run -d -p 8080:80 nginx — -d detached/background, -p HOST:CONTAINER maps host 8080 ->
container 80. Docker pulled the nginx image from Docker Hub (built in layers).
Opened port 8080 in ufw → reached the container's page at http://<ip>:8080
Concepts: image = template, container = running instance. Container is isolated from the host — own 
filesystem, own nginx — vs the system nginx on port 80 whose files live in /var/www/html. 
Two nginx instances, one droplet, fully separate.
Gotcha: Docker bypasses ufw. docker run -p 8080:80 exposed port 8080 to the internet even though 
ufw status showed only 22 and 80 allowed. Docker writes its own iptables rules 
below ufw, so ufw rules don't apply to published container ports. Real security risk — a container 
can be internet-exposed while the firewall appears to block it. Fix in production: 
bind to localhost (-p 127.0.0.1:8080:80) or configure Docker to respect ufw.

Droplet — serving my own files from a container (volume mount)
Made nginx container serve my own page instead of the default.

Made ~/mysite/index.html on the host
docker run -d -p 8080:80 -v /home/rocco/mysite:/usr/share/nginx/html nginx
-v HOST:CONTAINER mounts a host folder into the container. nginx's doc root inside the image is /usr/share/nginx/html. Host path must be absolute (pwd to get it).
Debugging: page showed the old default. docker exec <id> ls /usr/share/nginx/html proved my file was mounted correctly → it was browser cache. Hard-refresh (Cmd+Shift+R) fixed it.
New: docker exec runs a command inside a running container. docker ps -a shows stopped containers too. Containers don't auto-restart after reboot unless told to.
Concept: files live on the host, container runs them — edit on host, refresh, change appears. No rebuild. This is the host/container separation real deploys are built on.

Droplet — custom Docker image with a Dockerfile
Built my own image instead of mounting files at runtime.

~/mysite/Dockerfile:
FROM nginx
COPY index.html /usr/share/nginx/html
docker build -t mysite-image . (-t names/tags it, . = use Dockerfile in current dir)
docker run -d -p 8080:80 mysite-image — no -v, file is baked in
Syntax gotcha: COPY source dest is space-separated, not comma.
Proof it's baked in, not mounted: renamed the host index.html away → page still served, because the container has its own copy
 inside the image. A volume mount would have broken.
New: docker build, docker images (lists images = templates, vs docker ps = running containers). FROM = base image, COPY = copy 
files into image.
Concept: mount = host file borrowed live, edit-and-refresh, good for dev. Bake (Dockerfile) = self-contained portable image, 
good for production. Teams use both

Droplet — multi-service with docker-compose
Moved from docker run commands to a docker-compose.yml file, then added a second service.

yaml
services:
  web:
    image: mysite-image
    ports:
      - "8080:80"
  db:
    image: postgres
    environment:
      - POSTGRES_PASSWORD=...
docker compose up -d starts all services at once; docker compose ps lists them
compose auto-created a network (mysite_default) so containers reach each other by service name (web can find db — no IP needed)
web published 0.0.0.0:8080->80 (internet-facing); db showed only 5432/tcp (internal, not exposed) — because I mapped a port for web 
but not db. Safe default: not exposed.
New: docker-compose = containers defined in a file, started together. environment variables = config passed into a container at 
runtime (Postgres password), not baked in. Compose networking = service-name DNS between containers.
Concept: this is config-as-a-file instead of memorized commands — the on-ramp to Kubernetes, which is the same idea at scale.
Verified networking: docker compose exec web getent hosts db → returned db's internal IP. Web resolves db by service name.
(ping absent — nginx image is minimal, ships only what it needs.)

Cold rebuild redo — what I got wrong on my own
Tore down the stack and rebuilt from memory. The commands came back fine; the mental model was the weak part.

Ran docker compose down from ~ instead of ~/mysite → "no configuration file provided." compose reads the yml from the curren
directory. Had to cd in first.
Reached for docker run to rebuild — but that only starts one container by hand, skips the database and the network. 
The compose exercise needs docker compose up, which starts the whole stack from the file.
That manual docker run also grabbed port 8080, which would've collided with compose. Had to remove it first.
Confused "baking" with the run-vs-compose difference. Baking happens at docker build; both run and compose just launch 
already-built images. The real difference is run = one container manually, compose = whole stack from a file.
Takeaway: commands stuck, concepts needed retracing. Weak spot is which tool for what, not the syntax.

Docker Hub — pushing an image to a registry
Published my image so it's pullable from any machine.

docker login — authenticates the machine to Docker Hub (used an access token, like the GitHub token)
docker tag mysite-image roccomoreno/mysite-image — registry images must be named username/image. Tagging adds a second name to the 
same image (same IMAGE ID, no rebuild).
docker push roccomoreno/mysite-image — uploaded. My unique layer showed "Pushed"; the nginx/postgres base layers 
showed "Mounted from library/..." — Docker Hub already had them, so only my layer actually uploaded.
New: registry = where images live to be shared (Docker Hub is the default public one; I'd only ever pulled from it before). docker 
tag names images; docker push/pull move them between machine and registry.
Concept: completes the Docker arc — build → run → compose → ship. Layer sharing means images built on a common base don
't re-store the base; they share one copy and add only their difference.

Full Docker cold run — debrief
Did the whole arc from a wiped slate: build → run → compose up → verify networking → tag → push → wipe local → pull back. Happy path wa and unaided.
Gap: container/image lifecycle and sequencing. Kept jumping ahead a step.

docker stop pauses; docker rm removes. A stopped container still exists and still references its image.
docker rm = containers, docker rmi = images. Different tools.
docker compose down removes containers + network but NOT images — still need rmi for those.
Can't delete an image while any container (even stopped) references it. Order: down the stack → rmi the image → then it's gone.
Proof the registry copy is real: rmi until "Deleted", then pull shows layers downloading (not "up to date").
Takeaway: commands are fluent; the image→container→stopped→removed state machine is the part to drill.

compose build: vs image: — removing the footgun
Changed web service from image: mysite-image to build: . + image: mysite-image.

build: . tells compose to build from the Dockerfile at up time. image: still names the result (so tag/push still work).
Tested: wiped stack + image, ran one docker compose up -d → it built then started both containers, no separate build step, no "image not found."
Lesson: the sequencing mistake I kept making (forgetting to build first) is now structurally impossible — compose builds automatically. 
Fix the system so the error can't happen, don't just try to remember.

Flask app in a container — the application tier
Built a Python/Flask app that serves pages via code, not static files. First real "application" container (nginx just serves files unchanged).

app.py:

python
from flask import Flask
from datetime import datetime

app = Flask(__name__)

@app.route("/")
def home():
    return "<h1>Hello from Flask in a container</h1>"

@app.route("/time")
def time():
    return f"<h1>The time is {datetime.now()}</h1>"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

Dockerfile:

FROM python:3.12-slim
WORKDIR /app
COPY app.py .
RUN pip install flask
CMD ["python", "app.py"]

New Dockerfile instructions:

WORKDIR /app — sets working dir inside the image (like cd for the build)
RUN pip install flask — runs a command at build time, bakes the result into the image (installed Flask). Happens once, at build.
CMD ["python","app.py"] — the command run when the container starts (launches the app). Happens every start.
Lock it in: RUN = build-time, CMD = start-time.

Commands: docker build -t flaskapp . → docker run -d -p 5000:5000 flaskapp → sudo ufw allow 5000

docker logs <id> — shows a container's output. Saw Flask's "Running on 0.0.0.0:5000" startup. 
First tool to reach for when checking what's happening inside a container.

Key insight — routing: an app isn't one page, it's multiple routes. Each @app.route("URL") maps a URL to a function. / → home(), /time → time()
. Different URL = different function = different page. This is how every website is structured (/, /login, /profile...). 
Visiting /time ran Python fresh on each refresh (timestamp changed every load) = proof the page is computed, not a served file. 
(I'd expected both to show on one page — that's a different concept, JS updating part of a page. 
What I built is URL routing, the backbone of web app structure.)

Static vs dynamic: nginx serves a file unchanged; Flask runs code and returns the result. 
The app tier is the piece that can talk to a database — next step: wire Flask → Postgres.

Rebuild reminder: code is baked into the image, so changing app.py needs a full rebuild (remove container → build → run), not just a browser refresh
. Baked vs mounted, again. 
Only the container must be removed (it holds port 5000); the old image is superseded automatically and becomes 
a harmless dangling <none> image (docker image prune clears those).

Repo reorganization: split the homelab repo into mysite/ (nginx project) and flaskapp/ (Python project) folders, because both had a file 
named Dockerfile — dumping both in the root would've collided. 
Used git mv (moves a file and records it in git, preserving history, vs plain mv which looks like delete + create). 
Notes files (.md) stay in root; .env stays only on the droplet, never in git.

Flask → Postgres: three-tier stack working
Connected the app tier to the database tier. Browser → Flask → Postgres, all in one compose stack.

One docker-compose.yml runs both web (build: .) and db (postgres), both pulling POSTGRES_PASSWORD from .env.
app.py /db route: psycopg2.connect(host="db", ...) — connects to the DB by service name db (compose networking, same as getent hosts db). 
Runs SELECT version(), returns it.
Dockerfile: RUN pip install flask psycopg2-binary (install name is psycopg2-binary, import name is psycopg2; binary = precompiled, 
works in slim image without a compiler).

Debugging run (6 bugs, all read from error output):

.env “key cannot contain a space” → no spaces around = in .env.
“port 5000 already allocated” → old standalone flask container still running on 5000; docker rm -f it.
web container had empty PORTS → compose reused a half-formed container; docker compose down then up to recreate clean.
Internal Server Error → docker logs flaskapp-web-1 showed traceback → KeyError: 'POSTGRES_PASSWORD'. Cause: password was set under db but not web
. A var in .env only reaches a container if that service explicitly lists it in environment:. Added environment block to web.
“environment must be a mapping” → used _ (underscore) instead of - (hyphen) for the YAML list item.
“variable not set” warning → caught a scrambled typo (PASSOWRD).

New: docker logs <container> + reading a Python traceback (bottom line = the real error). KeyError = asked for a dict key that doesn’t exist. 
Env vars are per-container, not global.
Milestone: this is a real three-tier app — the thing everything was building toward.

Using the database — CRUD, persistence (SQL)
Added a /visitors route that creates a table, inserts a row each visit, and shows the running count. Jump from “connected to DB” to “using a DB.”

CREATE TABLE IF NOT EXISTS visitors (id SERIAL PRIMARY KEY, visited_at TIMESTAMP DEFAULT NOW()) — 
IF NOT EXISTS makes it safe to run every load; SERIAL = auto-incrementing id; DEFAULT NOW() = auto timestamp.
INSERT INTO visitors DEFAULT VALUES — adds a row (columns self-fill).
conn.commit() — writes aren’t saved until committed. execute stages, commit finalizes. SELECT (read) needs no commit; 
INSERT/UPDATE/DELETE (write) do. Forgetting commit = silent data loss.
SELECT COUNT(*) FROM visitors — counts rows; fetchone()[0] pulls the number out.
Each refresh → count climbs. docker compose restart web → count persists, because data lives in Postgres, not the app. That’s persistence.
New: SQL basics (CREATE/INSERT/SELECT), CRUD (Create/Read/Update/Delete = the 4 DB operations). --build on compose = pick up code changes (without it, 
restart reuses old image).
Debug: route crashed on startup — @app.route("visitors") missing the leading /. compose logs web → traceback named it: “must start with a slash.”

Three-tier cold redo — debrief
Rebuilt flask+postgres stack from torn-down state, mostly unaided. Build, compose up, log-reading all came back on their own.
Stumbles were typos, not concepts: docker build -t flaskapp (forgot the .), compose down (forgot docker), 
compose log webs (wrong: it’s docker compose logs web).
Real gap (repeated from last redo): mixing docker run and compose. 
Started a standalone docker run container on 5000, then compose up → “port already allocated,” twice
Fix each time was docker ps to see state, then docker rm -f the stray.
Rule to drill: once a project has a compose file, manage it ONLY with compose. Never docker run for it. docker run = one-off throwaway containers only. 
That rule alone prevents every port collision I hit.
Habit that saved me every time: docker ps before acting, to know actual state.

Droplet cleanup
Surveyed with docker ps -a + docker images. Removed the abandoned mysite stack with 
docker compose down (compose-managed → compose), a stray “Created” container with docker rm -f, then docker system prune -a fo
the three unused images plus build cache. Reclaimed 988MB.

docker system prune -a = removes stopped containers, unused networks, any image not used by a container, and build cache. 
Blunt — check the U (in use) column in docker images first so you know what it’ll take.
“Created” status = container made but never started (debris from a failed run).
End state: only flaskapp-web + db running.

Docker Desktop on Mac — local development
Installed Docker Desktop (Apple Silicon build for M3). Same engine and compose as the droplet.

Ran the flaskapp stack from the repo alone. Only missing piece was .env — gitignored by design, so recreated it locally. 
Verified with git status (“working tree clean” = .env ignored, can’t be pushed).
Each machine gets its own .env — same code, different secrets per environment.
localhost / 127.0.0.1 = the machine’s name for itself. Local containers are reached at localhost, no IP, no firewall step.

Port 5000 collision on macOS
compose up failed: “address already in use” on 5000, on a fresh machine. docker ps showed no container on 5000 → not Docker.
 lsof -i :5000 showed ControlCe = macOS Control Center / AirPlay Receiver, which listens on 5000.

lsof -i :PORT = shows which program holds a port (network connections count as files on Unix). 
Use when docker ps doesn’t explain a port conflict.
Fix: made the host port configurable — compose: "${WEB_PORT:-5000}:5000", Mac .env: WEB_PORT=5001. ${VAR:-default} = use VAR if set, 
else default. Droplet has no WEB_PORT → stays 5000. Same compose file everywhere, per-machine behavior from .env.
Only the host side changed; Flask inside the container still listens on 5000.

Visitor number 1 locally — Mac’s Postgres is a separate database from the droplet’s. Code is shared via git; data lives in 
each database.

Workflow flip: edit and test on the Mac, commit, then update the droplet from the repo — not the other way around.

WS — first EC2 instance
Opened an AWS account on the Free plan ($100 credits, closes after 6 months or when credits run out; no card attached, so nothing can bill). Region: US East (Ohio), us-east-2. Skipped root MFA for now — do it before adding a card or anything real.

EC2 = AWS’s virtual servers. Mapped every launch setting to the droplet:

Region = choosing the datacenter (where the server physically lives)
AMI (Amazon Machine Image) = the OS image, picked Ubuntu
Instance type = the plan size (CPU/RAM), picked a Free tier eligible one
Key pair = SSH key, but AWS generates it and hands me the private half (.pem), like the Bandit key files. macOS offered to add it to Keychain — cancelled, it’s an SSH key, not a certificate. Moved to ~/.ssh, chmod 400 (read-only for me).
Security group = AWS’s firewall

Connected: ssh -i ~/.ssh/1stAWSpair.pem ubuntu@<public-ip>. Username is ubuntu on AWS Ubuntu images, not root.

Installed nginx (sudo apt update first on a fresh server, then sudo apt install nginx), confirmed with sudo systemctl status nginx. Browser wouldn’t load.

Diagnosis: nginx running + sudo ufw status = inactive → nothing on the machine was blocking → the block was outside it. Security group only allowed SSH (port 22) from my IP. Added inbound rule: HTTP (port 80), source My IP → page loaded instantly, no restart.

Security group = firewall in AWS’s network, outside the server. Traffic must pass it before reaching the instance. On the droplet, ufw on the machine was the gate; on AWS the first gate is in the console.
Accounts have a default security group plus one per launch (launch-wizard-1). Find the right one via the instance’s Security tab.
CIDR: x.x.x.x/32 = exactly one IP (just me). 0.0.0.0/0 = entire internet.

Terminated the instance when done. Stop = powered off but disk kept (still costs). Terminate = deleted, nothing left to bill. Learning instances → always terminate.

Takeaway: the cloud is Linux servers you rent with a different control panel. Everything from the droplet transferred.

Deploying the flaskapp stack to AWS EC2
New account setup turned out to be AWS’s new sign-up experience (Sept 2026): signed in with a Builder ID, account lives in a “project” (“Fresh Deploy”) inside an AWS-managed Organization. There’s no root user until you upgrade, so no root MFA to set, and IAM users here are for programmatic access, not console login. AWS pre-builds the “don’t work as root” setup.

Saw roles in IAM: AccountFullAccessRole (last active “2 min ago”) = the role I’m signed in through. IAM role = identity with permissions but no permanent password; you assume it and get temporary credentials. Safer than long-lived passwords.
Spring cloud course will likely teach the classic model (root + IAM users + MFA). Same concepts.

The deploy:

Launched a fresh EC2 instance, reused the 1stAWSpair key pair (terminating an instance doesn’t delete its key pair). SSH: ssh -i ~/.ssh/1stAWSpair.pem ubuntu@<ip>. Username comes from the image: ubuntu on Ubuntu, ec2-user on Amazon Linux.
Installed Docker from docs.docker.com/engine/install/ubuntu (apt repository method). Verified with systemctl status docker and docker run hello-world.
sudo usermod -aG docker ubuntu, then exit and SSH back in (group membership loads at login).
git clone https://github.com/RoccoMoreno/homelab.git — repo came down with everything except .env (gitignored).
Created .env with just POSTGRES_PASSWORD=.... No WEB_PORT needed — that override was only for AirPlay on the Mac, so the compose default :-5000 applies. chmod 600 .env (a dot hides a file from ls, it doesn’t protect it).
docker compose up -d --build. (-p belongs to docker run; with compose, ports come from the file.)
Browser timed out → security group. Added the wrong rule first (HTTP = port 80). Fixed to Custom TCP, port 5000, My IP.

Debugging lessons:

“Took too long to respond” = timeout = something silently dropped the traffic (security group). “Refused to connect” = reached the machine, nothing listening on that port. Tells you which layer to check.
Each launch creates a new security group (launch-wizard-1, -2...). Always edit via the instance’s Security tab so you’re changing the group actually attached.
Only open the ports you use.

Same compose file now runs on three machines — droplet, Mac, and AWS — with per-environment differences living only in each .env.

Terminated the instance when done.

EC2 user data — the server sets itself up
Wrote flaskapp/user-data.sh and pasted it into Advanced details → User data at launch. App came up at :5000/visitors with no SSH at all.

User data = a script EC2 runs automatically on an instance’s first boot. cloud-init (a tool on the server) picks it up and runs it as root.
Wrote it as an outline of # comments first, then filled in each step from last session’s notes.

Rules for turning manual commands into a script:

Runs as root → drop every sudo.
Nobody to answer prompts → -y only where something would ask (apt-get install), not on update, curl, chmod, etc.
Use apt-get in scripts, not apt (stable for scripting; apt is for humans).
Skip steps a fresh machine doesn’t need (removing old Docker versions).
~ means root’s home in a root script → use absolute paths. Regular users’ homes are /home/<user>.
No hard-coded secrets (script lives in a public repo) → generate one on the server: echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)" > .env, then chmod 600 .env. Nobody needs to know it; web and db both read the same .env.
Root owns everything it creates → chown -R ubuntu:ubuntu /home/ubuntu/homelab/ so the ubuntu user can manage it later. Each Ubuntu user has a same-named group.
$ + a name = a variable. $JOESHOUSE123 would have become blank.

Before committing: chmod +x user-data.sh (execute permission), git status, check for secrets.
At launch: reused launch-wizard-2 (already had SSH + 5000), left “already base64 encoded” unchecked (AWS encodes plain text itself).
New: git remote -v shows the repo’s remote URLs. open <folder> opens it in Finder. pbcopy < file copies a file to the clipboard.
If a user data launch ever fails: SSH in and read /var/log/cloud-init-output.log.

GitHub Actions — CI for flaskapp
Added a workflow so every push to main builds the flaskapp Docker image on GitHub’s machines automatically.

Workflows must live in .github/workflows/ at the repo root. Made it with mkdir -p .github/workflows (-p = create parent folders too). .github starts with a dot, so it’s hidden.
build.yml:
yaml
name: Build flaskapp
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Build the Docker image
        run: docker build -t flaskapp flaskapp/
on: push = when to run. runs-on = GitHub gives a fresh Ubuntu machine (Docker preinstalled). uses: actions/checkout = pulls the repo onto it (the machine starts empty). run: = any shell command.
The job starts at the repo root, so the build path is flaskapp/ — relative, no leading /, pointing at the folder, not the Dockerfile.

Push rejected: token lacked the workflow scope. GitHub guards workflow files extra carefully because they run code and can access secrets. Added the scope by editing the classic token (same token value, keychain still works). Token expires Dec 8 — regenerate with repo + workflow.

Tested that it catches mistakes: broke the Dockerfile on purpose (xCOPY) → red X. Log showed Dockerfile:5, unknown instruction: xCOPY (did you mean copy?) — a parse error, failed before building anything. Fixed → green.

Exit code = number a command returns when it finishes. 0 = success, anything else = failure. CI marks a step red when its command exits non-zero.
Read CI logs like tracebacks: expand the failed step, the real error is near the bottom.

Habit: commit messages should say what changed (“Add CI workflow...”), not “check”.

Terraform — infrastructure as code
The launch clicks from earlier sessions are now a file. terraform/main.tf defines a security group (SSH + 5000 from my IP, all outbound) and a t3.micro instance with my user data script attached.

Setup on the Mac:

Homebrew = macOS package manager (like apt). Installed from brew.sh. On Apple Silicon it lives in /opt/homebrew, which isn’t on the PATH (the list of folders the shell searches for commands) until you run the “Next steps” lines that add it to ~/.zprofile (runs every new terminal). >> appends to a file; > overwrites.
AWS CLI: brew install awscli. aws login signs in through the browser and gives the CLI temporary credentials (up to 12 hrs) — no long-lived access key. It opens Safari (default browser); copied the URL into Chrome where I was signed in. Region us-east-2.
aws sts get-caller-identity = AWS’s whoami. Showed assumed-role/AccountFullAccessRole. ARN = AWS’s universal address for any resource.
Terraform: brew tap hashicorp/tap then brew install hashicorp/tap/terraform. A tap = an extra Homebrew catalog (like adding Docker’s apt repo).
Found free-tier types with the CLI: aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true --query "InstanceTypes[].InstanceType". Avoided t4g — g = Graviton (ARM), wouldn’t run my x86 AMI. Instance architecture must match the AMI.

The file:

provider "aws" = which cloud; picks up aws login credentials automatically.
resource "<type>" "<nickname>" = one thing to create.
ingress = inbound, egress = outbound. The console adds allow-all outbound automatically; Terraform doesn’t — without the egress block, apt and git clone would fail.
aws_security_group.flaskapp.id = a reference: Terraform fills in the real ID and knows to create the group first.
file("../flaskapp/user-data.sh") = attaches my script, path relative to terraform/.
output = prints the public IP when done.

Commands: terraform init (downloads the AWS provider) → terraform plan (shows what it would do, changes nothing — read the “Plan: X to add” line) → terraform apply (type yes) → terraform destroy. Destroy removed the instance first, then the security group — reverse of creation.

Declarative: the file describes the end state; Terraform makes reality match. Running apply twice changes nothing the second time.
(known after apply) = values AWS decides at creation (IP, IDs).

Git: .terraform.lock.hcl gets committed (pins provider version). Gitignored: .terraform/ (downloaded plugins) and *.tfstate (Terraform’s record of what it built — can hold sensitive values).

git add . from a subfolder only adds that folder and below — run it from the repo root.

Gotchas: macOS nano is really pico, which mangles big pastes (fused my lines). Wrote the file with pbpaste > main.tf instead. Cmd+T opens a new terminal tab.

Terraform part 2 — variables and data sources
Removed the two hard-coded values that would go stale.

Variables (my IP):

variables.tf: variable "my_ip" { type = string } — declares it.
main.tf: cidr_blocks = ["${var.my_ip}/32"] — var. references it; ${ } drops a value into a string (like bash $( )).
terraform.tfvars: my_ip = "..." — loaded automatically. Gitignored (home IP + public repo). Appended with echo "terraform.tfvars" >> ../.gitignore.
A security group IP rule is tied to the network, not the device — every device on my Wi-Fi shares one public IP. On another network, update one value and apply.

Data source (AMI):

data blocks read from AWS; resource blocks create.
Found the real image name: aws ec2 describe-images --image-ids <ami> --query "Images[].[Name,OwnerId]". I’ve been running Ubuntu 26.04 “resolute”, not 24.04.
data "aws_ami" "ubuntu" with most_recent = true, owners = ["099720109477"] (Canonical — guarantees the image is genuine, not a lookalike), and a name filter with the date replaced by *.
Instance uses ami = data.aws_ami.ubuntu.id — no quotes, it’s a reference.
Plan showed a newer AMI than the one I’d copied two days earlier.

Mistakes: left template [ ] brackets in values — Terraform said “An attribute name is required after a dot,” with file and line. The [ ] in templates always disappear. Read the plan’s last line before moving on.

Debugging a timeout layer by layer:

curl https://ifconfig.me = my current public IP (the % after it is zsh’s “no newline” marker).
terraform state show <resource> = what Terraform actually sent to AWS. terraform output = output values from state.
SSH worked → network path fine, problem isolated to port 5000.
cloud-init status --long → done, no errors. /var/lib/cloud/instance/user-data.txt = the script the server received.
docker ps → both containers up.
curl localhost:5000/visitors on the server → app works.
curl -m 10 http://<ip>:5000/visitors from the Mac → works (-m = timeout). The browser was the problem, most likely from trying before boot finished. Use http:// explicitly, fresh tab.
Split problems in half: test from inside the server, then from outside, then with the browser removed.
