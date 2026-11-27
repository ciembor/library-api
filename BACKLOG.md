# Backlog — API biblioteczne

## Cel i zakres MVP

API w Ruby on Rails i PostgreSQL pozwala pracownikowi dodać i usunąć książkę, przeglądać jej dostępność i historię wypożyczeń, rejestrować czytelnika oraz wypożyczać i zwracać książki. Wypożyczenie trwa 30 dni. System zapisuje treść przypomnienia 3 dni przed terminem zwrotu i w dniu zwrotu. Uwierzytelnianie, autoryzacja i rzeczywista wysyłka emaili są poza zakresem.

Zadania poniżej są ułożone w kolejności realizacji. Każde zadanie powinno kończyć się działającym, możliwym do sprawdzenia fragmentem systemu.

## Uzgodniony stack i standardy

| Element | Wybór |
| --- | --- |
| Framework | Ruby on Rails 8, API-only |
| Baza danych | PostgreSQL |
| Format API | `application/json` |
| Błędy | RFC 9457, `application/problem+json` |
| Dokumentacja | OpenAPI 3.1 |
| Dokumentacja testowana | Rswag oraz request specs RSpec |
| Zadania w tle | Active Job + Solid Queue |
| Maile | Action Mailer; w MVP zapis payloadu i logowanie |
| Testy | RSpec |
| Konteneryzacja | Docker Compose z trwałym named volume PostgreSQL |
| CI | GitHub Actions |
| Linter | RuboCop Rails Omakase z autokorektą |
| Jakość | Reek bez zapachów, 100% line i branch coverage, Mutant bez żywych mutacji |

## P0 — działające API

### 1. Szkielet aplikacji i uruchamianie

- [x] Utworzyć aplikację Rails w trybie API z PostgreSQL oraz `Dockerfile` i `compose.yaml`.
- [x] W Compose uruchamiać bazę, aplikację i proces Solid Queue; aplikacja czeka na gotowość bazy i wykonuje migracje przed startem.
- [x] Utrwalać dane PostgreSQL w named volume; przebudowa obrazu oraz odtworzenie kontenerów nie mogą usuwać danych.
- [x] Przygotować `GET /up` jako kontrolę zdrowia.
- [x] Po przebudowie obrazu z aktualnym bundle sprawdzić dostępność Rswag UI pod `/api-docs` i wygenerowanej specyfikacji pod `/api-docs/v1/swagger.yaml`.
- [x] Dodać krótki `README.md`: `docker compose up`, adres API i OpenAPI UI, przykładowe żądania, uruchamianie testów i decyzje projektowe.

**Akceptacja:** świeży checkout po `docker compose up` uruchamia API bez ręcznych kroków; ponowny start nie niszczy danych.

### 2. Schemat danych i reguły integralności

- [x] Dodać `books`: sześciocyfrowy `serial_number` (unikalny), niepusty `title`, niepusty `author`, opcjonalny `archived_at`.
- [x] Dodać `readers`: sześciocyfrowy `library_card_number` (unikalny), niepusty `full_name`, unikalny adres `email` porównywany bez względu na wielkość liter.
- [x] Dodać `borrowings`: klucze obce do książki i czytelnika, `borrowed_at`, `due_at`, opcjonalny `returned_at`.
- [x] W bazie i modelach wymusić format identyfikatorów, wymagane pola, unikalność oraz `due_at = borrowed_at + 30 dni` na poziomie operacji wypożyczenia.
- [x] Dodać częściowy unikalny indeks: jedna pozycja z `returned_at IS NULL` na książkę. Status książki wyliczać z aktywnego wypożyczenia, bez osobnej kolumny `status`.

**Akceptacja:** baza nie dopuszcza dwóch aktywnych wypożyczeń tej samej książki ani duplikatów numerów i adresów email.

### 3. Książki i czytelnicy

- [x] `POST /books` — dodać książkę; zwrócić `201` i jej dane.
- [x] `GET /books` — lista niearchiwalnych książek z polem `status: available|borrowed`; dodać prostą paginację i uniknąć zapytania do bazy osobno dla każdej pozycji.
- [x] `GET /books/:serial_number` — dane książki, status i pełna historia wypożyczeń, od najnowszego: data wypożyczenia, termin zwrotu, data zwrotu i dane czytelnika.
- [x] `DELETE /books/:serial_number` — archiwizować książkę i zwrócić `204`; odrzucić próbę archiwizacji wypożyczonej książki (`409`). Historia pozostaje w bazie, a numer seryjny nie jest ponownie używany.
- [x] `POST /readers` — rejestracja czytelnika, aby wypożyczenie mogło wskazać istniejący numer karty.
- [x] `GET /readers/:library_card_number` — odszukać czytelnika po numerze karty; brak rekordu zwraca `404`.
- [x] Wysyłać odpowiedzi sukcesu z treścią jako `application/json`; `DELETE` z kodem `204` nie ma treści, a techniczny `GET /up` nie należy do kontraktu JSON API.
- [x] Zdefiniować spójne błędy zgodne z RFC 9457 (`application/problem+json`) dla `400/404/409/422`: `type`, `title`, `status`, `detail` i opcjonalny `errors` dla pól.

**Akceptacja:** pracownik może dodać i odszukać książkę oraz czytelnika; lista pokazuje dostępność; szczegóły pokazują całą historię; archiwalna książka znika z listy, a jej historia pozostaje zachowana.

### 4. Wypożyczenie i zwrot

- [ ] `POST /books/:serial_number/borrowings` z `library_card_number` — utworzyć wypożyczenie dla istniejącego czytelnika; zwrócić `201` z `borrowed_at` i `due_at`.
- [ ] `POST /books/:serial_number/returns` — zamknąć bieżące wypożyczenie i zwrócić `200` z `returned_at`.
- [ ] Operacje zmiany stanu umieścić w małych obiektach `BorrowBook` i `ReturnBook`; kontrolery obsługują żądanie i odpowiedź, modele pilnują własnych danych, a baza chroni reguły integralności.
- [ ] Zabezpieczyć oba przejścia transakcją i blokadą wiersza książki; dla równoległych prób zachować jeden wynik sukcesu, a pozostałe zwracać jako `409`.
- [ ] Odrzucać wypożyczenie już wypożyczonej lub archiwalnej książki oraz zwrot książki dostępnej (`409`).

**Akceptacja:** cykl dostępna → wypożyczona → dostępna działa, historia nie jest nadpisywana, a równoległe żądania nie tworzą dwóch aktywnych wypożyczeń.

### 5. Przypomnienia o zwrocie

- [ ] Po wypożyczeniu zaplanować przez Active Job/Solid Queue dwa zadania: na `due_at - 3 dni` i `due_at`. Zadania wykonuje proces worker uruchamiany przez Compose.
- [ ] Przed przygotowaniem przypomnienia ponownie sprawdzić, czy wypożyczenie nadal jest aktywne. Po zwrocie nie tworzyć przypomnień.
- [ ] Generować przypomnienia Action Mailer i użyć adaptera zapisującego/logującego pełny payload: adres email, dane czytelnika, tytuł książki, numer seryjny, termin zwrotu i rodzaj przypomnienia.
- [ ] Dodać rejestr wysłanych przypomnień z unikalnym kluczem `(borrowing_id, kind)`, aby ponowienie zadania nie tworzyło duplikatu. W tym MVP „wysłanie” oznacza trwałe zapisanie payloadu i jego zalogowanie.

**Akceptacja:** aktywne wypożyczenie generuje dokładnie po jednym przypomnieniu w obu terminach; zwrot przed terminem je pomija; ponowne wykonanie zadania nie dubluje wpisu.

### 6. Testy i dokumentacja kontraktu

- [ ] Testy żądań dla wszystkich endpointów: poprawne odpowiedzi, walidacja, brak zasobu, konflikty i historia.
- [ ] Testy przepływu wypożyczenie/zwrot, ograniczenia bazy przy równoległych próbach oraz przypomnień z kontrolowanym czasem.
- [ ] Tworzyć request specs RSpec z Rswag jako źródło OpenAPI 3.1; zmienić wygenerowane `openapi: 3.0.1` na 3.1, generować plik i walidować go jako OpenAPI 3.1 oraz udostępnić Swagger UI pod `/api-docs`.
- [ ] Testować również odpowiedzi RFC 9457, typy MIME i kontrakt błędów.
- [ ] Utrzymać 100% line i branch coverage dla kodu `app/`, Reek bez ostrzeżeń, RuboCop po autokorekcie bez wykroczeń oraz Mutant bez żywych mutacji. Po dodaniu logiki domenowej wymagać co najmniej jednego podmiotu Mutant i rzeczywiście wykonanych mutacji; wynik `0 subjects / 0 mutations` nie potwierdza jakości testów mutacyjnych.
- [ ] Zmienić GitHub Actions na uruchamianie `bin/quality`, przygotowanie testowej bazy PostgreSQL oraz generowanie i weryfikację OpenAPI. Po autokorekcie RuboCop sprawdzać `git diff --exit-code`, żeby CI nie akceptowało kodu, który poprawiło tylko w swoim checkoutcie.
- [ ] W README podać przykładowe żądania i odpowiedzi JSON, opis kodów HTTP, sposób podglądu przypomnień oraz znane ograniczenia.
- [ ] Sprawdzić kompletne uruchomienie w czystym środowisku Compose oraz uruchomienie testów w kontenerze.

**Akceptacja:** opisane przykłady działają na świeżej bazie, testy przechodzą, a reviewer może zweryfikować przypomnienia bez konfiguracji zewnętrznego dostawcy email.

## Decyzje projektowe

- Numery identyfikacyjne to sześciocyfrowe liczby `100000..999999`; reguła jest egzekwowana także w bazie.
- `borrowed_at`, `due_at` i `returned_at` są znacznikami czasu przechowywanymi w UTC. „30 dni” oznacza dokładnie 30 dób od wypożyczenia; przypomnienia przypadają dokładnie 72 godziny przed terminem i w terminie.
- Czytelnik jest rejestrowany osobno. Historia wskazuje rekord czytelnika i pokazuje jego aktualne dane; w MVP nie ma edycji danych czytelnika.
- Archiwizacja zamiast fizycznego usunięcia chroni historię i zachowuje unikalność numeru seryjnego. Endpoint szczegółów może nadal udostępniać książkę archiwalną dla audytu.
- Wzorce stosujemy tam, gdzie rozwiązują konkretny problem: obiekty operacji dla przejść stanu, Active Job dla przypomnień, ograniczenia bazy dla współbieżności. Bez ogólnej warstwy repozytoriów i rozbudowanego frameworka serwisowego.

## P1 — po MVP, jeśli pojawi się potrzeba

- [ ] Filtry listy książek (`status`, tytuł, autor) i wyszukiwanie czytelników.
- [ ] Edycja czytelnika z ustaloną polityką danych historycznych (np. snapshot danych czytelnika przy wypożyczeniu).
- [ ] Prawdziwy adapter email i obserwowalność błędów dostarczenia; oddzielić zapis zamiaru wysyłki od faktycznego dostarczenia.
- [ ] Uwierzytelnianie i autoryzacja pracowników.
