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
