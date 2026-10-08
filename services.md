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
