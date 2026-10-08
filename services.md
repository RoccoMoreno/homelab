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
Replaced the default page with my own. nginx serves from /var/www/html; the default file is index.nginx-debian.html.

Found it: cd /var/www/html, cat confirmed it held the "Welcome to nginx!" HTML
sudo nano to edit (owned by root, needs sudo)
Wrote my own HTML, refreshed browser → live
Concept: document root — the folder a web server treats as the top of the site. Visiting the IP with no path makes nginx serve the index file from there.
