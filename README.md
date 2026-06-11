# BezpieczenstwoWebAppek

## Opis projektu
Aplikacja jest dostępna pod adresem [http://localhost](http://localhost). 

Projekt zawiera zautomatyzowany proces wdrażania aplikacji bWAPP. Tradycyjnie bWAPP wymaga ręcznej instalacji poprzez skrypt `/install.php`, jednak w tej konfiguracji proces ten został w pełni zautomatyzowany wewnątrz kontenerów, co pozwala na natychmiastowe rozpoczęcie pracy po uruchomieniu środowiska.

## Konfiguracja
Parametry bezpieczeństwa i działania aplikacji można konfigurować za pomocą pliku `.env`.

### Zmienne środowiskowe
- `RATE_LIMIT`: Średni limit zapytań na sekundę dla jednego adresu IP (np. `5r/s`).
- `BURST_LIMIT`: Maksymalny rozmiar bufora dla nagłych skoków ruchu (np. `10`).

## Docker
### Włączanie
```bash
docker compose up --build -d
```

### Wyłączanie
```bash
docker compose down -v
```

## Testowanie i weryfikacja

W celu weryfikacji wdrożonych zabezpieczeń (Rate Limiting, ochrona XSS za pomocą ModSecurity oraz ochrona CSRF za pomocą atrybutu `SameSite` na ciasteczkach sesyjnych) możesz przeprowadzić testy automatycznie lub ręcznie.

Aplikacja bWAPP jest dostępna bezpośrednio na porcie `8080` (brak zabezpieczeń), natomiast reverse proxy chroniący aplikację działa na porcie `80` (adres `http://localhost`).

---

### Metoda 1: Test automatyczny za pomocą skryptu

Uruchom skrypt `emulate-attacks.sh` podając jako argument adres, który chcesz przetestować:

#### A. Test z włączonym proxy (Zabezpieczenia AKTYWNE)
```bash
./emulate-attacks.sh http://localhost
```
*Wszystkie trzy testy powinny zakończyć się statusem **SUKCES**.*

#### B. Test bezpośrednio na aplikacji bWAPP (Zabezpieczenia NIEAKTYWNE)
```bash
./emulate-attacks.sh http://localhost:8080
```
*Wszystkie trzy testy powinny wykazać status **ZAGROŻENIE**.*

---

### Metoda 2: Testowanie ręczne (Komendy do skopiowania)

Jeśli chcesz przetestować każdą podatność z osobna bezpośrednio w terminalu, użyj poniższych komend.

#### 1. Test Ochrony przed Brute-Force / Rate Limiting

Symuluje serię 20 szybkich zapytań HTTP w celu przeciążenia limitu.

*   **Z zabezpieczeniem (Proxy):**
    ```bash
    for i in {1..20}; do curl -I -s -o /dev/null -w "%{http_code}\n" http://localhost/; done | sort | uniq -c
    ```
    *Spodziewany wynik:* Część zapytań zostanie odrzucona kodem `429` (np. `13 429` oraz `7 302` lub `200`).
*   **Bez zabezpieczenia (Bezpośrednio):**
    ```bash
    for i in {1..20}; do curl -I -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/; done | sort | uniq -c
    ```
    *Spodziewany wynik:* Wszystkie zapytania zakończą się sukcesem (`200` lub `302`).

#### 2. Test Ochrony przed XSS (Cross-Site Scripting)

Wysyła złośliwy ładunek `<script>alert('XSS')</script>` jako parametr zapytania.

*   **Z zabezpieczeniem (Proxy):**
    ```bash
    curl -I -s -o /dev/null -w "%{http_code}\n" "http://localhost/?q=%3Cscript%3Ealert('XSS')%3C/script%3E"
    ```
    *Spodziewany wynik:* Kod **`403`** (Forbidden) – ModSecurity blokuje niebezpieczne zapytanie.
*   **Bez zabezpieczenia (Bezpośrednio):**
    ```bash
    curl -I -s -o /dev/null -w "%{http_code}\n" "http://localhost:8080/?q=%3Cscript%3Ealert('XSS')%3C/script%3E"
    ```
    *Spodziewany wynik:* Kod **`200`** lub **`302`** – aplikacja akceptuje niebezpieczny ładunek.

#### 3. Test Ochrony przed CSRF (SameSite Cookie)

Sprawdza obecność atrybutu `SameSite=Lax` lub `SameSite=Strict` w nagłówku ciasteczka sesyjnego.

*   **Z zabezpieczeniem (Proxy):**
    ```bash
    curl -I -s http://localhost/portal.php | grep -i "Set-Cookie"
    ```
    *Spodziewany wynik:* Nagłówek `Set-Cookie` zawierający `; SameSite=Lax` na końcu.
*   **Bez zabezpieczenia (Bezpośrednio):**
    ```bash
    curl -I -s http://localhost:8080/portal.php | grep -i "Set-Cookie"
    ```
    *Spodziewany wynik:* Nagłówek `Set-Cookie` bez żadnej wzmianki o atrybucie `SameSite` (podatność na CSRF).
