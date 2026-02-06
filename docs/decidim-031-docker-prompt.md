# Optimierter Claude Code Prompt: Decidim 0.31 Docker Build

## Anleitung
Kopiere den Prompt unten in eine **frische Claude Code Session**.
Ersetze die Variablen (DOMAIN, PASSWÖRTER) nach Bedarf.

---

## Prompt (Copy & Paste)

```
Verbinde dich per SSH auf root@test.decidiem.de und baue eine Decidim 0.31.0 Docker-Installation von Grund auf. Der Server hat Ubuntu 24.04, Docker und Caddy sind bereits installiert.

WICHTIG – Lies diese Hinweise BEVOR du anfängst, sie sparen dir mehrere fehlgeschlagene Builds:

### Bekannte Fallstricke (aus 6 fehlgeschlagenen Build-Versuchen gelernt):

1. RUBY VERSION: Decidim 0.31.0 braucht Ruby 3.3, NICHT 3.2
2. ESCAPING: Schreibe KEINE mehrzeiligen Dateien mit echo oder heredoc über SSH. 
   Nutze stattdessen: ssh root@... 'cat > /pfad/datei << "EOFMARKER"' mit quoted EOFMARKER
   Oder: Erstelle zuerst eine lokale Datei, dann scp auf den Server
3. GEMS: Decidim 0.31 braucht zusätzlich: gem "pg", "~> 1.5" und gem "redis", "~> 4.1"
   Schreibe ein separates Ruby-Script (add_gems.rb) das die Gems zum Gemfile hinzufügt,
   statt Shell-Escaping in echo-Befehlen zu riskieren
4. ORGANISATION NAME: Muss ein i18n-Hash sein: {"en" => "Name"}, NICHT ein einfacher String
5. PASSWORT POLICY: Org-Admin Passwort muss mindestens 15 Zeichen lang sein
6. FARBEN: Nach Organisation-Erstellung MÜSSEN Farben gesetzt werden, sonst sind Buttons unsichtbar:
   org.colors = {"primary"=>"#2ecc71","secondary"=>"#1abc9c","success"=>"#28a745","warning"=>"#ffc107","alert"=>"#dc3545"}
7. SYSTEM ADMIN ≠ ORG ADMIN: Das sind zwei verschiedene Tabellen (Decidim::System::Admin vs Decidim::User)

### Schritt-für-Schritt-Anleitung:

SCHRITT 1: Alte Container stoppen
  cd /opt/decidim && docker compose down -v

SCHRITT 2: Build-Verzeichnis erstellen
  mkdir -p /opt/decidim/build

SCHRITT 3: Dateien erstellen (jeweils einzeln, mit quoted heredoc):

a) /opt/decidim/build/Dockerfile:
   - FROM ruby:3.3-slim-bookworm
   - System-Dependencies: build-essential, libpq-dev, nodejs (20.x), npm, git, curl, libicu-dev, imagemagick
   - npm install -g yarn
   - gem install decidim-generator -v 0.31.0
   - decidim my_app (generiert die App)
   - Separates Ruby-Script für zusätzliche Gems (add_gems.rb)
   - bundle install
   - RAILS_ENV=production bundle exec rails assets:precompile
   - Entrypoint-Script kopieren

b) /opt/decidim/build/add_gems.rb:
   File.open("Gemfile", "a") do |f|
     f.puts 'gem "pg", "~> 1.5"'
     f.puts 'gem "redis", "~> 4.1"'
   end

c) /opt/decidim/build/database.yml:
   Einfache Konfiguration die DATABASE_URL aus ENV liest

d) /opt/decidim/build/entrypoint.sh:
   - Warte auf PostgreSQL (pg_isready Loop)
   - rails db:create (ignoriere Fehler falls DB existiert)
   - rails db:migrate
   - exec rails server -b 0.0.0.0 -p 3000

e) /opt/decidim/docker-compose.yml:
   Services: db (postgres:15-alpine), redis (redis:7-alpine), decidim (build from ./build)
   decidim environment: DATABASE_URL, REDIS_URL, SECRET_KEY_BASE (generieren!), 
   RAILS_ENV=production, RAILS_SERVE_STATIC_FILES=true, RAILS_LOG_TO_STDOUT=true
   Port: 127.0.0.1:3000:3000 (nur localhost, Caddy macht den Rest)

SCHRITT 4: Image bauen
  cd /opt/decidim && docker compose build --no-cache decidim
  (Dauert 10-15 Minuten, NICHT abbrechen)

SCHRITT 5: Container starten
  docker compose up -d
  (Warte 30 Sekunden, dann prüfe mit docker compose ps und docker logs decidim-app)

SCHRITT 6: System-Admin erstellen
  docker exec decidim-app bundle exec rails runner "
    Decidim::System::Admin.create!(
      email: 'system.test@decidiem.de',
      password: 'literal:<REDACTED>',
      password_confirmation: 'literal:<REDACTED>'
    )
  "

SCHRITT 7: Organisation erstellen
  docker exec decidim-app bundle exec rails runner "
    org = Decidim::Organization.create!(
      name: {'en' => 'Decidim Test'},
      host: 'test.decidiem.de',
      default_locale: 'en',
      available_locales: ['en', 'de'],
      reference_prefix: 'test',
      available_authorizations: [],
      users_registration_mode: 0
    )
    org.colors = {
      'primary' => '#2ecc71',
      'secondary' => '#1abc9c',
      'success' => '#28a745',
      'warning' => '#ffc107',
      'alert' => '#dc3545'
    }
    org.save!
  "

SCHRITT 8: Org-Admin erstellen (Passwort mind. 15 Zeichen!)
  docker exec decidim-app bundle exec rails runner "
    org = Decidim::Organization.first
    user = Decidim::User.create!(
      email: 'admin@test.decidiem.de',
      name: 'Admin',
      nickname: 'admin',
      password: 'literal:<REDACTED>',
      password_confirmation: 'literal:<REDACTED>',
      organization: org,
      confirmed_at: Time.current,
      locale: 'en',
      admin: true,
      tos_agreement: true,
      accepted_tos_version: org.tos_version
    )
  "

SCHRITT 9: Verifizieren
  curl -sI https://test.decidiem.de | head -5
  (Sollte HTTP 200 zurückgeben)

### Erwartetes Ergebnis:
- decidim-custom:0.31.0 Image gebaut
- 3 Container laufen (app, db, redis)
- https://test.decidiem.de zeigt Decidim mit grünen Buttons
- /system Login: system.test@decidiem.de / literal:<REDACTED>
- /admin Login: admin@test.decidiem.de / literal:<REDACTED>
```

---

## Varianten

### Für docker.decidiem.de
Ersetze alle Vorkommen von `test.decidiem.de` durch `docker.decidiem.de`
und passe die Mail-Adressen entsprechend an.

### Für eine komplett neue Installation (inkl. Docker + Caddy)
Füge vor SCHRITT 1 hinzu:
```
SCHRITT 0: Docker und Caddy installieren
  apt-get update && apt-get install -y ca-certificates curl gnupg
  # Docker CE installieren (offizielle Anleitung)
  # Caddy installieren (offizielles Repo)
  # Caddyfile: test.decidiem.de { reverse_proxy localhost:3000 }
```

### Mit Modulen (Awesome, Geo, Term Customizer)
Erweitere add_gems.rb:
```ruby
File.open("Gemfile", "a") do |f|
  f.puts 'gem "pg", "~> 1.5"'
  f.puts 'gem "redis", "~> 4.1"'
  f.puts 'gem "decidim-decidim_awesome", "~> 0.11"'
  f.puts 'gem "decidim-geo"'
  f.puts 'gem "decidim-term_customizer"'
end
```

---

## Zeitmessung

| Phase | Erwartet | Tatsächlich (Session 1) |
|-------|----------|------------------------|
| Container stoppen + Dateien erstellen | 2-3 Min | ~5 Min (Escaping-Probleme) |
| Docker Build | 10-15 Min | ~30 Min (6 Versuche) |
| Setup (Admin, Org, Farben) | 2-3 Min | ~5 Min |
| Verifizierung | 1 Min | 1 Min |
| **Gesamt** | **~20 Min** | **~50 Min** |

**Ziel mit optimiertem Prompt: < 20 Minuten, 1 Build-Versuch.**
