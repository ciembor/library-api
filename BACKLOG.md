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

- [x] `POST /books/:serial_number/borrowings` z `library_card_number` — utworzyć wypożyczenie dla istniejącego czytelnika; zwrócić `201` z `borrowed_at` i `due_at`.
- [x] `POST /books/:serial_number/returns` — zamknąć bieżące wypożyczenie i zwrócić `200` z `returned_at`.
- [x] Operacje zmiany stanu umieścić w małych obiektach `BorrowBook` i `ReturnBook`; kontrolery obsługują żądanie i odpowiedź, modele pilnują własnych danych, a baza chroni reguły integralności.
- [x] Zabezpieczyć oba przejścia transakcją i blokadą wiersza książki; dla równoległych prób zachować jeden wynik sukcesu, a pozostałe zwracać jako `409`.
- [x] Odrzucać wypożyczenie już wypożyczonej lub archiwalnej książki oraz zwrot książki dostępnej (`409`).

**Akceptacja:** cykl dostępna → wypożyczona → dostępna działa, historia nie jest nadpisywana, a równoległe żądania nie tworzą dwóch aktywnych wypożyczeń.

### 5. Przypomnienia o zwrocie

- [x] Po wypożyczeniu zaplanować przez Active Job/Solid Queue dwa zadania: na `due_at - 3 dni` i `due_at`. Zadania wykonuje proces worker uruchamiany przez Compose.
- [x] Przed przygotowaniem przypomnienia ponownie sprawdzić, czy wypożyczenie nadal jest aktywne. Po zwrocie nie tworzyć przypomnień.
- [x] Generować przypomnienia Action Mailer i użyć adaptera zapisującego/logującego pełny payload: adres email, dane czytelnika, tytuł książki, numer seryjny, termin zwrotu i rodzaj przypomnienia.
- [x] Dodać rejestr wysłanych przypomnień z unikalnym kluczem `(borrowing_id, kind)`, aby ponowienie zadania nie tworzyło duplikatu. W tym MVP „wysłanie” oznacza trwałe zapisanie payloadu i jego zalogowanie.

**Akceptacja:** aktywne wypożyczenie generuje dokładnie po jednym przypomnieniu w obu terminach; zwrot przed terminem je pomija; ponowne wykonanie zadania nie dubluje wpisu.

### 6. Testy i dokumentacja kontraktu

- [x] Testy żądań dla wszystkich endpointów: poprawne odpowiedzi, walidacja, brak zasobu, konflikty i historia.
- [x] Testy przepływu wypożyczenie/zwrot, ograniczenia bazy przy równoległych próbach oraz przypomnień z kontrolowanym czasem.
- [x] Tworzyć request specs RSpec z Rswag jako źródło OpenAPI 3.1; zmienić wygenerowane `openapi: 3.0.1` na 3.1, generować plik i walidować go jako OpenAPI 3.1 oraz udostępnić Swagger UI pod `/api-docs`.
- [x] Testować również odpowiedzi RFC 9457, typy MIME i kontrakt błędów.
- [x] Utrzymać 100% line i branch coverage dla kodu `app/`, Reek bez ostrzeżeń, RuboCop po autokorekcie bez wykroczeń oraz Mutant bez żywych mutacji. Po dodaniu logiki domenowej wymagać co najmniej jednego podmiotu Mutant i rzeczywiście wykonanych mutacji; wynik `0 subjects / 0 mutations` nie potwierdza jakości testów mutacyjnych.
- [x] Zmienić GitHub Actions na uruchamianie `bin/quality`, przygotowanie testowej bazy PostgreSQL oraz generowanie i weryfikację OpenAPI. Po autokorekcie RuboCop sprawdzać `git diff --exit-code`, żeby CI nie akceptowało kodu, który poprawiło tylko w swoim checkoutcie.
- [x] W README podać przykładowe żądania i odpowiedzi JSON, opis kodów HTTP, sposób podglądu przypomnień oraz znane ograniczenia.
- [x] Sprawdzić kompletne uruchomienie w czystym środowisku Compose oraz uruchomienie testów w kontenerze.

**Akceptacja:** opisane przykłady działają na świeżej bazie, testy przechodzą, a reviewer może zweryfikować przypomnienia bez konfiguracji zewnętrznego dostawcy email.

### 7. Uzupełnienie testów po audycie przypadków brzegowych

Audyt z 2026-11-27: istniejące request specs pokrywają podstawowe ścieżki API, a testy modeli i bazy sprawdzają wiele ograniczeń. 100% line/branch coverage nie oznacza pokrycia wszystkich wartości granicznych, wyścigów ani awarii infrastruktury. Poniższe zadania uzupełniają milestone 6; jego zaznaczone zadania opisują dotychczasową realizację, a nie potwierdzenie scenariuszy poniżej.

#### P0 — wiarygodność gate’ów i integralność przy współbieżności

- [ ] **Naprawić zakres mutation testing po refaktorach.** `bin/mutation-quality` nadal wskazuje nieistniejące `Borrowing#due_at_matches_borrowed_at` i `Borrowing#returned_at_follows_borrowed_at`. Objąć rzeczywiste metody `BorrowingTimestampsValidator` i `BorrowingTimestampConstraints`, `PaginationParameters` oraz logikę przypomnień. Zapewnić dobór testów dla nowych klas (obecne testy walidacji opisują `Borrowing`). **Akceptacja:** każdy wymagany selektor dopasowuje metody i wykonuje testy oraz mutacje; usunięty/przemianowany selektor powoduje błąd gate’u, nawet gdy pozostałe selektory działają. Brak żywych mutacji w zadeklarowanym zakresie. Uruchamiać ten sam gate także w CI, które obecnie nie wywołuje `bin/mutation-quality`.
- [ ] **Sprawdzić rzeczywistą współbieżność wypożyczeń i zwrotów.** Dwie próby wypożyczenia tej samej książki i dwa zwroty jednego wypożyczenia na oddzielnych połączeniach PostgreSQL, z barierą synchronizacji i ograniczonym czasem oczekiwania. Obecne mockowanie `Book.lock` i sekwencyjne inserty nie dowodzą zachowania równoległego. **Akceptacja:** jedno powodzenie, jeden konflikt, jedna poprawna zmiana stanu i zachowana historia; przygotowane dane widoczne dla obu połączeń, niezależnie od transakcyjnych fixtures.
- [ ] **Sprawdzić wyścig archiwizacji z wypożyczeniem.** `BooksController#destroy` sprawdza dostępność i archiwizuje bez blokady używanej przez `BorrowBook`. **Akceptacja:** kontrolowany test równoległy dowodzi, że nie powstaje archiwalna książka z nowym aktywnym wypożyczeniem; wynik odpowiada jednej kolejności operacji. Jeśli test ujawni błąd, objąć obie operacje wspólną ochroną stanu.
- [ ] **Sprawdzić wyścigi przypomnień.** Równoległe wykonanie tego samego joba oraz zwrot między odczytem aktywnego wypożyczenia a zapisem przypomnienia. **Akceptacja:** jeden rekord i jedno logowanie dla `(borrowing_id, kind)`; dla zwrotu zakończonego przed zapisem przypomnienia nie powstaje przypomnienie. Ustalić i zabezpieczyć punkt rozstrzygnięcia kolejności operacji.
- [ ] **Sprawdzić awarie planowania i zapisu przypomnień.** Błąd lub niepowodzenie enqueue pierwszego/drugiego joba, błąd zapisu payloadu i ponowienie operacji. `BorrowBook` planuje zadania po transakcji wypożyczenia. **Akceptacja:** testy najpierw ujawniają stan po częściowej awarii; uzgodniony mechanizm odzyskiwania nie pozostawia aktywnego wypożyczenia bez dwóch zaplanowanych przypomnień i nie tworzy duplikatów. Osobno udokumentować zachowanie przy błędzie logowania po trwałym zapisie payloadu.

#### P0 — wejście API i wartości graniczne

- [ ] **Paginacja: parser oraz request specs.** Sprawdzić `page=1`, `per_page=1/100`, zero i wartości ujemne obu parametrów, puste wartości, `null`, liczby ułamkowe, tablice/obiekty (`page[]=1`, `per_page[x]=1`), dwa niepoprawne parametry jednocześnie oraz bardzo duży `page`, którego offset przekracza zakres PostgreSQL. **Akceptacja:** poprawne granice są akceptowane, błędne wejście daje pojedyncze `400 application/problem+json`, bez `500` i podwójnego renderowania. Ustalić dopuszczalne reprezentacje liczb (spacje, znak plus, zera wiodące, zapis wykładniczy) i sprawdzić je jawnie; sprawdzić także własne wartości domyślne i maksymalne konstruktora parsera.
- [ ] **Niepoprawna struktura żądań i identyfikatory.** Dla `book`, `reader`, `borrowing` sprawdzić pusty obiekt, `null`, string, liczbę i tablicę zamiast obiektu, uszkodzony JSON oraz brak `library_card_number` w niepustym payloadzie. Sprawdzić identyfikatory w URL i payloadzie: `100000/999999`, brak wartości, ułamki, tekst z sufiksem (`123456abc`), liczby poza zakresem. **Akceptacja:** granice poprawne działają, błędne wejście nie wskazuje innego istniejącego rekordu przez konwersję typu, nie zmienia danych i otrzymuje uzgodnione `400/404/422` zgodne z OpenAPI, bez `500`.
- [ ] **Duplikaty i pola chronione przez API.** Request specs dla duplikatu numeru książki (także archiwalnej), karty i emaila różniącego się wielkością liter oraz wyścigu rejestracji czytelników. Sprawdzić próby ustawienia `archived_at`, `status`, `borrowed_at`, `due_at`, `returned_at` i wewnętrznych identyfikatorów przez klienta. **Akceptacja:** duplikaty zwracają `422` i nie dodają rekordów; niedozwolone pola nie zmieniają stanu ani terminu wypożyczenia.

#### P1 — pełne scenariusze, czas i kontrakt

- [ ] **Pełny cykl i archiwum przez HTTP.** Dodać scenariusz utworzenie → wypożyczenie → zwrot → ponowne wypożyczenie innemu czytelnikowi → zwrot → archiwizacja. **Akceptacja:** dwa odrębne wpisy historii z właściwymi czytelnikami i datami, dostępne szczegóły archiwalnej książki, brak jej na liście, zachowana rezerwacja numeru oraz konflikt przy ponownym zwrocie. Sprawdzić także pustą historię i uzgodnić kolejność przy identycznych `borrowed_at`.
- [ ] **Pusta lista, ostatnia strona i brak N+1.** Sprawdzić pustą bazę, listę samych archiwalnych książek, stronę poza końcem i niepełną ostatnią stronę. **Akceptacja:** `data: []` tam, gdzie właściwe, poprawne `meta.total` bez archiwalnych rekordów, stabilne sortowanie; liczba zapytań listy i historii nie rośnie liniowo z liczbą książek/wypożyczeń (pomiar SQL albo strict loading).
- [ ] **Granice dat i precyzja.** Sprawdzić `returned_at == borrowed_at` (obecny kod dopuszcza równość), zwrot tuż przed wypożyczeniem, termin krótszy/dłuższy o sekundę i precyzję mikrosekund po odczycie z PostgreSQL. Dodać koniec miesiąca/roku, rok przestępny i zmianę czasu w strefie z DST. **Akceptacja:** model, walidator i baza są zgodne; termin wynosi dokładnie 30 × 24 godziny, przypomnienie 72 godziny wcześniej; komunikat błędu odpowiada regule równości.
- [ ] **Przypomnienia z kontrolowanym czasem i Solid Queue.** Obecne testy sprawdzają planowane timestampy i wywołują `perform_now`, ale nie sprawdzają wykonania przez worker. Dodać test przejścia przez oba terminy, zwrotu między przypomnieniami, spóźnionego wykonania po przestoju oraz ponownego wypożyczenia tej samej książki (stare joby nie dotyczą nowego wypożyczenia). **Akceptacja:** każde aktywne wypożyczenie ma po jednym payloadzie obu rodzajów, zwrócone jest pomijane; `sent_at`, adresat, tytuł, numer i termin są poprawne. Osobny test integracyjny potwierdza trwałość zadań i wykonanie po restarcie workera Solid Queue.
- [ ] **Wzmocnić asercje kontraktu i serializerów.** W oczekiwanych payloadach czytelnika używać jawnych wartości zamiast wywołania produkcyjnego `ReaderSerializer`, aby błąd serializera nie zmieniał równocześnie wyniku i oczekiwania. Sprawdzić brak `errors` dla problemu bez błędów pól, `about:blank`, własny `type` w ścieżce renderowania oraz zgodność statusu HTTP i body. Uzupełnić schemat typów `meta.page/per_page/total` i wymagalność `borrowings` w szczegółach książki. **Akceptacja:** usunięcie wymaganego pola lub zmiana typu powoduje błąd testu kontraktu; jawnie sprawdzane są `returned_at: null`, pusta historia i brak pól wewnętrznych.
- [ ] **Powtarzalny smoke test Compose i trwałości danych.** W izolowanym projekcie Compose utworzyć książkę, czytelnika i wypożyczenie, przebudować obrazy i odtworzyć kontenery bez usuwania wolumenu. **Akceptacja:** dane i historia nadal istnieją, API oraz `/api-docs/v1/swagger.yaml` są dostępne, worker podejmuje zapisane zadania. Test nie używa deweloperskiej bazy ani jej wolumenu.

**Akceptacja milestone 7:** powyższe luki mają testy zachowania na właściwym poziomie, wykryte błędy są naprawione, a raport mutation testing jawnie wskazuje rzeczywiście sprawdzany zakres. Zielone coverage i CI nie zastępują testów współbieżności ani integracji z kolejką.

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
