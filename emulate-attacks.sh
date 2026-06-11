#!/bin/bash

# Adres URL celu (domyślnie http://localhost)
TARGET_URL="${1:-http://localhost}"

# Kolory dla lepszej czytelności
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}        URUCHAMIANIE TESTÓW BEZPIECZEŃSTWA        ${NC}"
echo -e "${BLUE}        Cel: ${YELLOW}$TARGET_URL${NC}"
echo -e "${BLUE}==================================================${NC}"
echo

# 1. Test Rate Limiting / Brute-Force
echo -e "${YELLOW}[1] Testowanie Rate Limiting / Ochrony przed Brute-Force...${NC}"
echo "Wysyłanie 20 szybkich zapytań HTTP..."
results=$(for i in {1..20}; do curl -I -s -o /dev/null -w "%{http_code}\n" "$TARGET_URL/"; done)
codes_summary=$(echo "$results" | sort | uniq -c)

echo "Podsumowanie kodów HTTP:"
echo "$codes_summary"

if echo "$results" | grep -q "429"; then
    echo -e "${GREEN}[+] SUKCES: Wykryto ograniczenie liczby żądań (zwrócono kod HTTP 429 Too Many Requests).${NC}"
else
    echo -e "${RED}[-] ZAGROŻENIE: Brak ograniczenia liczby żądań. Serwer nie zablokował zapytań (brak kodu HTTP 429).${NC}"
fi
echo

# Krótkie opóźnienie, aby zresetować rate limit dla kolejnych testów
sleep 2

# 2. Test XSS (Cross-Site Scripting)
echo -e "${YELLOW}[2] Testowanie ochrony przed XSS...${NC}"
xss_payload="%3Cscript%3Ealert('XSS')%3C/script%3E"
echo -e "Wysyłanie ładunku XSS w parametrze URL: ${BLUE}$TARGET_URL/?q=$xss_payload${NC}"
http_code=$(curl -I -s -o /dev/null -w "%{http_code}" "$TARGET_URL/?q=$xss_payload")

echo "Uzyskany kod HTTP: $http_code"

if [ "$http_code" = "403" ]; then
    echo -e "${GREEN}[+] SUKCES: Atak XSS został zablokowany przez Web Application Firewall (kod HTTP 403 Forbidden).${NC}"
else
    echo -e "${RED}[-] ZAGROŻENIE: Atak XSS NIE został zablokowany (kod HTTP $http_code). Serwer zaakceptował żądanie.${NC}"
fi
echo

# Krótkie opóźnienie, aby uniknąć limitowania dla CSRF
sleep 2

# 3. Test CSRF (SameSite Cookie Protection)
echo -e "${YELLOW}[3] Testowanie ochrony przed CSRF (Atrybut SameSite)...${NC}"
echo -e "Sprawdzanie obecności atrybutu SameSite w nagłówku Set-Cookie z: ${BLUE}$TARGET_URL/portal.php${NC}"

# Pobranie nagłówka Set-Cookie z portal.php lub login.php
cookie_headers=$(curl -I -s "$TARGET_URL/portal.php" | grep -i "Set-Cookie")
if [ -z "$cookie_headers" ]; then
    cookie_headers=$(curl -I -s "$TARGET_URL/login.php" | grep -i "Set-Cookie")
fi

if [ -n "$cookie_headers" ]; then
    # Usunięcie znaku nowej linii na końcu, jeśli istnieje
    cookie_headers=$(echo "$cookie_headers" | tr -d '\r\n')
    echo "Nagłówek odpowiedzi: $cookie_headers"
    
    if echo "$cookie_headers" | grep -iq "SameSite"; then
        samesite_val=$(echo "$cookie_headers" | grep -o -i "SameSite=[a-zA-Z]*")
        echo -e "${GREEN}[+] SUKCES: Wykryto ochronę SameSite ($samesite_val) w ciasteczku sesyjnym. Przeglądarka zablokuje automatyczne wysyłanie sesji w atakach CSRF.${NC}"
    else
        echo -e "${RED}[-] ZAGROŻENIE: Brak atrybutu SameSite w ciasteczku sesyjnym. Sesja użytkownika jest podatna na ataki CSRF.${NC}"
    fi
else
    echo -e "${YELLOW}[!] OSTRZEŻENIE: Serwer nie zwrócił nagłówka Set-Cookie (brak aktywnej sesji). Upewnij się, że cel jest uruchomiony.${NC}"
fi

echo
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}                 KONIEC TESTÓW                    ${NC}"
echo -e "${BLUE}==================================================${NC}"
