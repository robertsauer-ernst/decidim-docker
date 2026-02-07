# Install Log: test.decidiem.de – Decidim 0.31.0 Docker Build

**Datum:** 06.02.2026  
**Server:** test.decidiem.de (CX23, 46.225.56.88)  
**Durchgeführt mit:** Claude Code (Opus 4.6)  
**Gesamtdauer:** ~67 Minuten (Phase 1: 17 Min, Phase 2: 50 Min)

---

## Phase 1: Vanilla-Installation mit offiziellem Image (17 Min)

### Auftrag
Ubuntu 24.04 frisch installiert → Docker + Caddy + Decidim via Docker Compose

### Schritte
1. Docker CE 29.2.1 installiert
2. Caddy 2.10.2 installiert (Reverse Proxy, automatisches Let's Encrypt)
3. `docker-compose.yml` erstellt mit `ghcr.io/decidim/decidim:latest`, PostgreSQL 15, Redis 7
4. SECRET_KEY_BASE generiert (`openssl rand -hex 64`)
5. Caddyfile konfiguriert: `test.decidiem.de → localhost:3000`
6. Container gestartet, DB-Migration ausgeführt
7. System-Admin und Organisation per Rails Console angelegt

### Ergebnis
- ✅ HTTP 200 auf https://test.decidiem.de
- ⚠️ `ghcr.io/decidim/decidim:latest` = **Decidim 0.24** (Rails 5.2) – veraltet!

### Zugangsdaten (Phase 1)
| Bereich | URL | Email | Passwort |
|---------|-----|-------|----------|
| System-Panel | /system | admin@test.decidiem.de | <REDACTED> |
| Frontend-Admin | /admin | admin@test.decidiem.de | <REDACTED> |

---

## Phase 2: Custom Docker Image – Decidim 0.31.0 (50 Min)

### Auftrag
Eigenes Dockerfile mit Decidim 0.31.0 von Source bauen

### Build-Versuche

| # | Ansatz | Ergebnis | Problem |
|---|--------|----------|---------|
| 1 | `FROM ruby:3.2-slim-bookworm` | ❌ | Decidim 0.31 braucht Ruby 3.3 |
| 2 | `FROM ruby:3.3-slim-bookworm` | ❌ | Fehlende System-Dependencies (libpq-dev etc.) |
| 3 | Dockerfile mit Escaping-Fix | ❌ | Shell-Escaping über SSH korrumpierte Dockerfile |
| 4 | Gemfile-Einträge korrigiert | ❌ | `gem "redis"` Versionskonflikt |
| 5 | Redis-Version auf `~> 4.1` gefixt | ❌ | Noch Escaping-Probleme in echo-Befehlen |
| 6 | Separates `add_gems.rb` Script | ✅ | Build `b14b0c6` erfolgreich |

### Finale Build-Konfiguration
- **Base Image:** `ruby:3.3-slim-bookworm`
- **Decidim:** 0.31.0 (generiert mit `decidim my_app`)
- **Rails:** 7.2.2.2
- **Ruby:** 3.3.10
- **zusätzliche Gems:** `pg ~> 1.5`, `redis ~> 4.1`
- **Assets:** vorkompiliert im Image

### Dateien auf dem Server
```
/opt/decidim/
├── docker-compose.yml
├── build/
│   ├── Dockerfile
│   ├── database.yml
│   ├── entrypoint.sh
│   └── add_gems.rb
```

### Container (laufend)
| Container | Image | Status |
|-----------|-------|--------|
| decidim-app | decidim-custom:0.31.0 | Running |
| decidim-db | postgres:15-alpine | Healthy |
| decidim-redis | redis:7-alpine | Healthy |

### Zugangsdaten (Phase 2 – final)
| Bereich | URL | Email | Passwort |
|---------|-----|-------|----------|
| System-Panel | /system | admin@test.decidiem.de | <REDACTED> |
| Org-Admin | /admin | admin@test.decidiem.de | <REDACTED> |

---

## Post-Install Fixes

### 1. Farben-Bug (bekannt von demo.decidiem.de)
**Problem:** Organisation hat keine Farben → Buttons unsichtbar (weiß auf weiß)  
**Ursache:** Decidim 0.31 setzt keine Default-Farben bei Organisation-Erstellung  
**Fix:**
```ruby
docker exec decidim-app bundle exec rails runner "
  org = Decidim::Organization.first
  org.colors = {
    'primary' => '#2ecc71',
    'secondary' => '#1abc9c',
    'success' => '#28a745',
    'warning' => '#ffc107',
    'alert' => '#dc3545'
  }
  org.save!
"
```
**Status:** ✅ Gefixt

### 2. ActiveJob Queue nicht konfiguriert
**Problem:** System-Check zeigt Warnung im /system Dashboard  
**Fix:** Sidekiq als separaten Container einrichten  
**Status:** ⏳ Offen

---

## Bekannte Bugs (für GitHub Issues)

1. **Farben-Bug:** Neue Organisationen haben `colors: {}` → kein CSS für Buttons
2. **SMTP `enable_starttls_auto`:** Wird als String statt Boolean übergeben
3. **`:latest` Tag veraltet:** Zeigt auf 0.24 statt aktuelle Version
4. **Organisation-Name:** Muss i18n-Hash sein, nicht String (Fehlermeldung unklar)
5. **Passwort-Policy:** Org-Admin braucht längeres Passwort als System-Admin, keine klare Rückmeldung

---

## Offene Punkte

- [ ] SMTP einrichten (securemail.name, Port 587, STARTTLS) mit `enable_starttls_auto` Fix
- [ ] Sidekiq-Container für Background Jobs
- [ ] Module ins Dockerfile: Decidim Awesome, Geo, Term Customizer
- [ ] User anlegen: Johann, Will, Mohamed (mit deren eigenen E-Mail-Adressen)
- [ ] OAuth zwischen Instanzen konfigurieren
- [ ] Git-Repo für Build-Dateien erstellen
- [ ] Mail-Adressen systematisieren: `noreply.test@decidiem.de`, `system.test@decidiem.de`

---

## Infrastruktur-Übersicht (Stand 06.02.2026)

| Server | Subdomain | Typ | Version | Status |
|--------|-----------|-----|---------|--------|
| decidim-demo | demo.decidiem.de | Native (bare metal) | 0.31.1 | ✅ Produktion |
| docker-decidim | test.decidiem.de | Docker (custom image) | 0.31.0 | ✅ Läuft |
| docker-decidim-2 | docker.decidiem.de | Docker (ghcr 0.31.rc2) | 0.31.0.rc2 | ✅ Läuft |

---

## Lessons Learned

1. **Claude Code Kontext-Limit:** Bei 1% Kontext angekommen – komplexe Aufträge besser in kleinere Schritte aufteilen
2. **SSH-Escaping:** Verschachtelte Anführungszeichen über SSH sind fehleranfällig → separate Dateien/Scripts verwenden
3. **Decidim `latest` ≠ aktuell:** Offizielles Image seit Jahren nicht aktualisiert
4. **Farben sind kein CSS-Bug:** Sondern fehlende DB-Einträge – muss bei jeder neuen Organisation gesetzt werden
5. **Zwei Admin-Systeme:** System-Admin (Decidim::System::Admin) ≠ Org-Admin (Decidim::User mit admin:true) – verschiedene Tabellen, verschiedene Passwörter
