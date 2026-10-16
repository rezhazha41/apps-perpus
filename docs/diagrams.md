# Diagram Sistem Perpus

Dokumen ini mendeskripsikan struktur dan alur aplikasi Perpus berbasis Flutter dan Supabase self-hosted. Diagram menggunakan Mermaid sehingga dapat dirender di GitHub, GitLab, atau editor Markdown yang mendukung Mermaid.

## 1. Use Case Diagram

```mermaid
flowchart LR
  Anggota([Anggota / Siswa])
  Pengurus([Pengurus / Admin])
  Sistem((Sistem Perpus))

  Anggota --> UC1[Daftar dengan NIS/NISN]
  Anggota --> UC2[Login dan kelola akun]
  Anggota --> UC3[Lihat katalog]
  Anggota --> UC4[Scan QR buku]
  Anggota --> UC5[Pilih selfie/kartu siswa]
  Anggota --> UC6[Ajukan peminjaman]
  Anggota --> UC7[Ajukan pengembalian]
  Anggota --> UC8[Laporkan kehilangan]
  Anggota --> UC9[Lihat status dan riwayat]

  Pengurus --> UC10[Setujui/tolak akun anggota]
  Pengurus --> UC11[Kelola katalog dan stok]
  Pengurus --> UC12[Generate/cetak QR buku]
  Pengurus --> UC13[Setujui/tolak peminjaman]
  Pengurus --> UC14[Proses pengembalian]
  Pengurus --> UC15[Verifikasi kehilangan]
  Pengurus --> UC16[Buat sesi pembelajaran]
  Pengurus --> UC17[Kelola anggota dan kebijakan]

  Sistem -.-> UC1
  Sistem -.-> UC6
  Sistem -.-> UC11
  Sistem -.-> UC13
  Sistem -.-> UC16
```

## 2. Flowchart pengajuan peminjaman

```mermaid
flowchart TD
  A([Mulai]) --> B[Anggota login]
  B --> C[Scan QR buku]
  C --> D{Buku tersedia?}
  D -- Tidak --> E[Tampilkan buku tidak tersedia]
  D -- Ya --> F[Pilih selfie atau kartu siswa]
  F --> G[Ambil dan unggah bukti privat]
  G --> H{Bukti valid dan lengkap?}
  H -- Tidak --> I[Tampilkan pesan perbaikan]
  H -- Ya --> J[Ajukan peminjaman]
  J --> K[Server membuat status pending]
  K --> L[Pengurus memeriksa anggota, bukti, dan QR]
  L --> M{Disetujui?}
  M -- Tidak --> N[Simpan alasan penolakan]
  M -- Ya --> O[Lock anggota dan eksemplar]
  O --> P[Validasi ulang stok dan batas pinjaman]
  P --> Q{Masih valid?}
  Q -- Tidak --> R[Gagal atomik tanpa stok berubah]
  Q -- Ya --> S[Loan dibuat dan QR menjadi borrowed]
  S --> T([Selesai])
  E --> T
  I --> T
  N --> T
  R --> T
```

## 3. ERD basis data

```mermaid
erDiagram
  STUDENT_REGISTRY ||--o{ PROFILES : "claim siswa"
  STAFF_REGISTRY ||--o| PROFILES : "akun pengurus"
  BOOKS ||--o{ BOOK_COPIES : memiliki
  PROFILES ||--o{ LOAN_REQUESTS : membuat
  LOAN_REQUESTS ||--|{ LOAN_REQUEST_ITEMS : berisi
  BOOK_COPIES ||--o{ LOAN_REQUEST_ITEMS : diajukan
  LOAN_REQUESTS ||--o| TRANSACTION_EVIDENCE : memiliki
  LOAN_REQUESTS ||--o| LOANS : disetujui_menjadi
  LOANS ||--|{ LOAN_ITEMS : memiliki
  BOOK_COPIES ||--o{ LOAN_ITEMS : dipinjam
  LOANS ||--o{ RETURN_REQUESTS : diminta
  RETURN_REQUESTS ||--|{ RETURN_REQUEST_ITEMS : berisi
  LOAN_ITEMS ||--o{ RETURN_REQUEST_ITEMS : dikembalikan
  LOAN_ITEMS ||--o| LOSS_REPORTS : dilaporkan
  PROFILES ||--o{ CLASS_LOAN_SESSIONS : membuat
  CLASS_LOAN_SESSIONS ||--|{ CLASS_LOAN_ITEMS : berisi
  BOOK_COPIES ||--o{ CLASS_LOAN_ITEMS : dipakai

  STUDENT_REGISTRY {
    uuid id PK
    text nis
    text nisn
    text name
    boolean active
  }
  STAFF_REGISTRY {
    uuid id PK
    text email
    text role
    boolean active
  }
  PROFILES {
    uuid id PK
    uuid student_id FK
    uuid staff_id FK
    text role
    text status
  }
  BOOKS {
    uuid id PK
    text title
    text author
    text category
    text isbn
    timestamptz archived_at
  }
  BOOK_COPIES {
    uuid id PK
    uuid book_id FK
    text code UK
    text status
    timestamptz archived_at
  }
  LOAN_REQUESTS {
    uuid id PK
    uuid member_id FK
    text status
    text rejection_reason
  }
  LOAN_REQUEST_ITEMS {
    uuid request_id FK
    uuid copy_id FK
  }
  TRANSACTION_EVIDENCE {
    uuid id PK
    uuid request_id FK
    text method
    text storage_path
  }
  LOANS {
    uuid id PK
    uuid request_id FK
    uuid member_id FK
    text status
    timestamptz due_at
  }
  LOAN_ITEMS {
    uuid id PK
    uuid loan_id FK
    uuid copy_id FK
    text status
    timestamptz returned_at
  }
  RETURN_REQUESTS {
    uuid id PK
    uuid loan_id FK
    text status
  }
  RETURN_REQUEST_ITEMS {
    uuid request_id FK
    uuid loan_item_id FK
  }
  LOSS_REPORTS {
    uuid id PK
    uuid loan_item_id FK
    text status
    text resolution_note
  }
  CLASS_LOAN_SESSIONS {
    uuid id PK
    uuid created_by FK
    text class_name
    text activity
    timestamptz due_at
  }
  CLASS_LOAN_ITEMS {
    uuid session_id FK
    uuid copy_id FK
    text status
  }
```

`auth.users`, `storage.objects`, `library_settings`, `audit_logs`, dan `account_recovery_challenges` adalah komponen pendukung Supabase. RLS membatasi akses langsung; perubahan transaksi dilakukan melalui RPC.

## 4. Class Diagram

```mermaid
classDiagram
  class Book {
    +String id
    +String title
    +String author
    +String category
    +String code
    +String description
  }
  class BookCopy {
    +String code
    +String bookId
    +CopyStatus status
  }
  class Student {
    +String id
    +String name
    +String className
    +String nis
    +bool active
  }
  class LoanItem {
    +String id
    +String studentId
    +String copyCode
    +DateTime borrowedAt
    +DateTime dueAt
    +DateTime returnedAt
    +bool isOpen()
    +bool isOverdue(DateTime now)
  }
  class BorrowRequest {
    +String id
    +String studentId
    +List~String~ copyCodes
    +EvidenceMethod evidence
    +RequestStatus status
  }
  class DemoLibrary {
    +List~Book~ books
    +List~BookCopy~ copies
    +List~Student~ students
    +submit(codes, evidence)
    +approve(request)
    +receive(loan, code)
    +reportLoss(loan)
  }
  Book "1" --> "many" BookCopy
  Student "1" --> "many" LoanItem
  BorrowRequest "1" --> "many" BookCopy
  DemoLibrary o-- Book
  DemoLibrary o-- BookCopy
  DemoLibrary o-- Student
  DemoLibrary o-- BorrowRequest
  DemoLibrary o-- LoanItem
```

## 5. Sequence Diagram persetujuan peminjaman

```mermaid
sequenceDiagram
  actor A as Anggota
  actor P as Pengurus
  participant UI as Flutter
  participant API as Supabase API/RLS
  participant DB as PostgreSQL RPC
  participant ST as Storage privat

  A->>UI: Scan QR dan pilih bukti
  UI->>ST: Upload foto bukti
  ST-->>UI: Path bukti privat
  A->>UI: Ajukan peminjaman
  UI->>API: submit_loan_request
  API->>DB: Validasi anggota, QR, dan bukti
  DB-->>API: pending
  API-->>UI: Pengajuan menunggu
  P->>UI: Buka antrean dan bukti
  UI->>API: review_loan_request
  API->>DB: Lock dan validasi ulang
  DB-->>API: approved atau rejected
  API-->>UI: Status keputusan
  UI-->>A: Riwayat dan status terbaru
```

## 6. Activity Diagram pengembalian sebagian

```mermaid
flowchart TD
  A([Mulai]) --> B[Anggota memilih pinjaman aktif]
  B --> C[Ajukan pengembalian]
  C --> D[Pengurus membuka scanner]
  D --> E[Scan QR buku fisik]
  E --> F{QR cocok dengan loan item?}
  F -- Tidak --> G[Tolak penerimaan dan tampilkan pesan]
  F -- Ya --> H[Pilih kondisi baik atau rusak]
  H --> I[RPC menerima satu item]
  I --> J{Masih ada item aktif?}
  J -- Ya --> K[Pinjaman tetap aktif sebagian]
  J -- Tidak --> L[Pinjaman selesai]
  K --> M[Stok tersedia/rusak diperbarui]
  L --> M
  M --> N([Selesai])
  G --> N
```

## 7. Component Diagram

```mermaid
flowchart LR
  subgraph Client[Flutter Android]
    Auth[Auth pages]
    Member[Member features]
    Staff[Staff features]
    QR[QR scanner and printer]
    Domain[Domain models and rules]
    Demo[DemoLibrary]
  end
  subgraph Server[Supabase self-hosted]
    Gateway[API Gateway / PostgREST]
    GoTrue[GoTrue Auth]
    RLS[RLS policies]
    RPC[Transactional RPC]
    DB[(PostgreSQL)]
    Storage[Private Storage]
    Recovery[account-recovery Edge Function]
  end
  Auth --> GoTrue
  Member --> Gateway
  Staff --> Gateway
  QR --> Member
  QR --> Staff
  Gateway --> RLS
  RLS --> RPC
  RPC --> DB
  Member --> Storage
  Staff --> Storage
  Auth --> Recovery
  Client -. mode demo .-> Demo
  Domain --> Member
  Domain --> Staff
```

## 8. Deployment Diagram

```mermaid
flowchart TB
  Phone1[HP anggota\nFlutter APK]
  Phone2[HP pengurus\nFlutter APK]
  LAN[(Wi-Fi / LAN sekolah)]
  NPM[Nginx Proxy Manager\nHTTPS reverse proxy]
  Supabase[Server lokal]
  Auth[Supabase Auth / GoTrue]
  API[PostgREST + RPC]
  PG[(PostgreSQL)]
  Obj[(Storage privat)]

  Phone1 --> LAN
  Phone2 --> LAN
  LAN --> NPM
  NPM --> Supabase
  Supabase --> Auth
  Supabase --> API
  API --> PG
  API --> Obj
```

## Batasan dokumentasi

- Diagram menggambarkan arsitektur dan alur yang disepakati; status implementasi tetap mengikuti bukti pada `docs/implementation-status.md` dan laporan E2E.
- Integrasi GoTrue, Storage, dan concurrency PostgreSQL perlu diuji pada lingkungan terisolasi sebelum disebut lulus produksi.
- Demo memakai penyimpanan memori dan tidak boleh digunakan untuk data siswa nyata.
