# Backlog — API biblioteczne

## Cel i zakres MVP

API w Ruby on Rails i PostgreSQL pozwala pracownikowi dodać i usunąć książkę, przeglądać jej dostępność i historię wypożyczeń, rejestrować czytelnika oraz wypożyczać i zwracać książki. Wypożyczenie trwa 30 dni. System zapisuje treść przypomnienia 3 dni przed terminem zwrotu i w dniu zwrotu. Uwierzytelnianie, autoryzacja i rzeczywista wysyłka emaili są poza zakresem.

Zadania poniżej są ułożone w kolejności realizacji. Każde zadanie powinno kończyć się działającym, możliwym do sprawdzenia fragmentem systemu.

## P0 — działające API

### 1. Szkielet aplikacji i uruchamianie

- [ ] Utworzyć aplikację Rails w trybie API z PostgreSQL oraz `Dockerfile` i `compose.yaml`.
- [ ] W Compose uruchamiać bazę, aplikację i proces wykonujący zadania w tle; aplikacja czeka na gotowość bazy i wykonuje migracje przed startem.
- [ ] Przygotować `GET /up` jako kontrolę zdrowia.
- [ ] Dodać krótki `README.md`: `docker compose up`, adres API, przykładowe żądania, uruchamianie testów i decyzje projektowe.

**Akceptacja:** świeży checkout po `docker compose up` uruchamia API bez ręcznych kroków; ponowny start nie niszczy danych.

### 2. Schemat danych i reguły integralności

- [ ] Dodać `books`: sześciocyfrowy `serial_number` (unikalny), niepusty `title`, niepusty `author`, opcjonalny `archived_at`.
- [ ] Dodać `readers`: sześciocyfrowy `library_card_number` (unikalny), niepusty `full_name`, unikalny adres `email` porównywany bez względu na wielkość liter.
- [ ] Dodać `borrowings`: klucze obce do książki i czytelnika, `borrowed_at`, `due_at`, opcjonalny `returned_at`.
- [ ] W bazie i modelach wymusić format identyfikatorów, wymagane pola, unikalność oraz `due_at = borrowed_at + 30 dni` na poziomie operacji wypożyczenia.
- [ ] Dodać częściowy unikalny indeks: jedna pozycja z `returned_at IS NULL` na książkę. Status książki wyliczać z aktywnego wypożyczenia, bez osobnej kolumny `status`.

**Akceptacja:** baza nie dopuszcza dwóch aktywnych wypożyczeń tej samej książki ani duplikatów numerów i adresów email.

### 3. Książki i czytelnicy

- [ ] `POST /books` — dodać książkę; zwrócić `201` i jej dane.
- [ ] `GET /books` — lista niearchiwalnych książek z polem `status: available|borrowed`; dodać prostą paginację i uniknąć zapytania do bazy osobno dla każdej pozycji.
- [ ] `GET /books/:serial_number` — dane książki, status i pełna historia wypożyczeń, od najnowszego: data wypożyczenia, termin zwrotu, data zwrotu i dane czytelnika.
- [ ] `DELETE /books/:serial_number` — archiwizować książkę i zwrócić `204`; odrzucić próbę archiwizacji wypożyczonej książki (`409`). Historia pozostaje w bazie, a numer seryjny nie jest ponownie używany.
- [ ] `POST /readers` — rejestracja czytelnika, aby wypożyczenie mogło wskazać istniejący numer karty.
- [ ] Ustalić spójne odpowiedzi błędów JSON dla `400/404/409/422` i udokumentować je w README.

**Akceptacja:** pracownik może dodać i odszukać książkę oraz czytelnika; lista pokazuje dostępność; szczegóły pokazują całą historię; archiwalna książka znika z listy, a jej historia pozostaje zachowana.

### 4. Wypożyczenie i zwrot

- [ ] `POST /books/:serial_number/borrowings` z `library_card_number` — utworzyć wypożyczenie dla istniejącego czytelnika; zwrócić `201` z `borrowed_at` i `due_at`.
- [ ] `POST /books/:serial_number/returns` — zamknąć bieżące wypożyczenie i zwrócić `200` z `returned_at`.
- [ ] Operacje zmiany stanu umieścić w małych obiektach `BorrowBook` i `ReturnBook`; kontrolery obsługują żądanie i odpowiedź, modele pilnują własnych danych, a baza chroni reguły integralności.
- [ ] Zabezpieczyć oba przejścia transakcją i blokadą wiersza książki; dla równoległych prób zachować jeden wynik sukcesu, a pozostałe zwracać jako `409`.
- [ ] Odrzucać wypożyczenie już wypożyczonej lub archiwalnej książki oraz zwrot książki dostępnej (`409`).

**Akceptacja:** cykl dostępna → wypożyczona → dostępna działa, historia nie jest nadpisywana, a równoległe żądania nie tworzą dwóch aktywnych wypożyczeń.

### 5. Przypomnienia o zwrocie

- [ ] Po wypożyczeniu zaplanować dwa zadania: na `due_at - 3 dni` i `due_at`. Zadania wykonuje proces worker uruchamiany przez Compose.
- [ ] Przed przygotowaniem przypomnienia ponownie sprawdzić, czy wypożyczenie nadal jest aktywne. Po zwrocie nie tworzyć przypomnień.
- [ ] Zapisywać lub logować pełny payload: adres email, dane czytelnika, tytuł książki, numer seryjny, termin zwrotu i rodzaj przypomnienia.
- [ ] Dodać rejestr wysłanych przypomnień z unikalnym kluczem `(borrowing_id, kind)`, aby ponowienie zadania nie tworzyło duplikatu. W tym MVP „wysłanie” oznacza trwałe zapisanie payloadu i jego zalogowanie.

**Akceptacja:** aktywne wypożyczenie generuje dokładnie po jednym przypomnieniu w obu terminach; zwrot przed terminem je pomija; ponowne wykonanie zadania nie dubluje wpisu.

### 6. Testy i dokumentacja kontraktu

- [ ] Testy żądań dla wszystkich endpointów: poprawne odpowiedzi, walidacja, brak zasobu, konflikty i historia.
- [ ] Testy przepływu wypożyczenie/zwrot, ograniczenia bazy przy równoległych próbach oraz przypomnień z kontrolowanym czasem.
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
