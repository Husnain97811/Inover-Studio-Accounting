<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=6,12,20&height=220&section=header&text=IS%20Accounting&fontSize=60&fontColor=ffffff&fontAlignY=36&desc=Pakistan%27s%20Offline-First%20ERP%20System&descAlignY=55&descColor=C49A4A&descSize=20&animation=twinkling" width="100%"/>

</div>

<div align="center">

[![Typing SVG](https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=22&pause=1000&color=0B6B43&center=true&vCenter=true&width=600&lines=Built+for+Pakistani+SMEs+%F0%9F%87%B5%F0%9F%87%B0;100%25+Offline-First+%E2%80%94+Works+Without+Internet;FBR+POS+Integrated+%E2%80%94+Auto+USIN+%2B+QR;Flutter+Desktop+%2B+Supabase+%2B+Drift)](https://git.io/typing-svg)

</div>

---

<div align="center">

## 🛠️ Tech Stack

</div>

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Postgres](https://img.shields.io/badge/postgres-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)
![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)

![Riverpod](https://img.shields.io/badge/Riverpod-State_Management-0B6B43?style=for-the-badge)
![Drift](https://img.shields.io/badge/Drift-ORM_%2F_SQLite-C49A4A?style=for-the-badge)
![GoRouter](https://img.shields.io/badge/GoRouter-Navigation-02569B?style=for-the-badge)
![FBR](https://img.shields.io/badge/FBR-POS_Integrated-006400?style=for-the-badge)

</div>

<br/>

---

<div align="center">

## 📊 Project Stats

</div>

<div align="center">

| | |
|:---:|:---:|
| ![](https://img.shields.io/badge/Tables-19_DB_Tables-0B6B43?style=flat-square&labelColor=0d1117) | ![](https://img.shields.io/badge/Screens-10_Screens-C49A4A?style=flat-square&labelColor=0d1117) |
| ![](https://img.shields.io/badge/Platforms-Windows_%2B_macOS-02569B?style=flat-square&labelColor=0d1117) | ![](https://img.shields.io/badge/Offline-100%25_First-0B6B43?style=flat-square&labelColor=0d1117) |
| ![](https://img.shields.io/badge/FBR-USIN_%2B_QR_Auto-C49A4A?style=flat-square&labelColor=0d1117) | ![](https://img.shields.io/badge/Urdu-RTL_Support-3ECF8E?style=flat-square&labelColor=0d1117) |
| ![](https://img.shields.io/badge/License-Device_Locked-red?style=flat-square&labelColor=0d1117) | ![](https://img.shields.io/badge/Multi--Tenant-RLS_Isolated-316192?style=flat-square&labelColor=0d1117) |

</div>

<br/>

---

## 🚀 What is IS Accounting?

**IS Accounting** is a production-grade, offline-first ERP system built specifically for Pakistani small and medium businesses. It works fully without internet — every sale, product update, and customer record saves instantly to local SQLite. When connectivity returns, everything syncs to Supabase automatically.

```
94% of Pakistani SMEs have no ERP. This is built for them.
```

> 🏪 Retail · 🏥 Medical / Pharmacy · 🍽️ Restaurant · 📱 Electronics · 📚 Bookshop · 👗 Clothing · 🚚 Distribution

<br/>

---

## ✨ Features

<table>
<tr>
<td width="50%" valign="top">

### ✅ Phase 1 — Shipped

```
🛒  POS Terminal
    ├── Keyboard-first (F1–F12 shortcuts)
    ├── Barcode scanner support
    ├── Cash / Card / Credit / Online
    └── Change calculator

📦  Inventory
    ├── Per-branch stock levels
    ├── Low stock alerts
    ├── PCT code per product
    └── Barcode + SKU

🧾  FBR POS Compliance
    ├── Auto USIN generation
    ├── QR code on receipt
    ├── Retry queue (offline safe)
    └── PCT codes per line item

👥  Customers
    ├── CNIC / NTN for FBR
    ├── Credit (Udhaar) ledger
    └── Balance tracking

📊  Dashboard
    ├── Today's KPIs
    ├── Hourly sales chart
    ├── FBR sync status
    └── Low stock alerts

🔄  Offline Sync
    ├── Outbox pattern
    ├── Last-Write-Wins
    └── 30s background sync

🔐  License System
    ├── Device fingerprint (SHA-256)
    ├── Offline expiry enforcement
    └── 3-day grace period

اردو  Urdu / English
    ├── Hot-swap toggle
    └── RTL layout support
```

</td>
<td width="50%" valign="top">

### 🔵 Phase 2 — In Progress

```
🛍️  Purchase Orders
    ├── Vendor management
    ├── GRN (Goods Receipt)
    └── Accounts Payable

📒  General Ledger
    ├── Pakistan standard COA
    ├── Double-entry journals
    ├── Trial Balance
    └── P&L + Balance Sheet

💰  Cash & Bank
    ├── Cash drawer management
    └── Bank reconciliation

📋  Reports
    ├── FBR monthly return
    ├── Sales by period
    ├── Inventory valuation
    └── Customer aging

💬  WhatsApp Invoicing
    └── Send receipt without
        saving contact

🏢  Branch Management
    ├── Add multiple branches
    └── Per-branch cashiers
```

### 🟡 Phase 3 — Planned

```
👷  HR & Payroll     (EOBI/SESSI)
🏭  Manufacturing    (BOM + orders)
🤝  Basic CRM        (follow-ups)
📱  Mobile App       (iOS + Android)
```

</td>
</tr>
</table>

<br/>

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                  FLUTTER DESKTOP APP                         │
│               Windows  ·  macOS                              │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌────────────────┐  │
│  │  Riverpod    │───▶│ Drift SQLite │───▶│ Outbox Queue   │  │
│  │  State Mgmt  │    │  Local DB    │    │ (pending sync) │  │
│  └──────────────┘    └──────────────┘    └───────┬────────┘  │
│                                                  │            │
│  Every write is INSTANT — no internet needed     │            │
└──────────────────────────────────────────────────┼───────────┘
                                                   │ SyncEngine
                                                   │ (30s loop)
                                         ┌─────────▼──────────┐
                                         │    SUPABASE        │
                                         │  ┌──────────────┐  │
                                         │  │ PostgreSQL   │  │
                                         │  │ + RLS        │  │
                                         │  └──────────────┘  │
                                         │  ┌──────────────┐  │
                                         │  │ Auth + JWT   │  │
                                         │  └──────────────┘  │
                                         │  ┌──────────────┐  │
                                         │  │ Edge Fns     │  │
                                         │  │ (licensing)  │  │
                                         │  └──────────────┘  │
                                         └────────────────────┘
```

<br/>

---

## 🗃️ Database — 19 Tables

```
📁 is_accounting.db (SQLite — on device)
│
├── 🔐 LICENSING
│   ├── device_licenses          ← activated devices + expiry
│
├── 🏢 BUSINESS CORE
│   ├── tenants                  ← one row per business
│   ├── branches                 ← one row per shop/location
│   └── user_profiles            ← staff with roles
│
├── 📦 PRODUCTS & STOCK
│   ├── product_categories       ← hierarchical categories
│   ├── products                 ← catalog with PCT codes
│   └── inventory                ← qty_on_hand per branch
│
├── 🧾 SALES & FINANCE
│   ├── customers                ← CNIC/NTN + Udhaar balance
│   ├── invoices                 ← FBR status, USIN, QR
│   ├── invoice_items            ← line items with tax
│   ├── vendors                  ← suppliers (Phase 2)
│   ├── purchase_orders          ← POs (Phase 2)
│   └── purchase_order_items     ← PO lines (Phase 2)
│
├── 📒 ACCOUNTING
│   ├── accounts                 ← Pakistan standard COA
│   ├── journal_entries          ← double-entry headers
│   └── journal_lines            ← debit / credit lines
│
└── 🔄 SYNC ENGINE
    ├── outbox_queue             ← pending cloud writes
    └── sync_watermarks          ← last pull timestamps
```

> **Same schema in Supabase PostgreSQL** — run `supabase/rls_setup.sql` to create cloud tables.

<br/>

---

## 🔐 Multi-Tenancy — How It Works

One Supabase project serves **unlimited businesses**, fully isolated:

```
Ahmed Traders  (tenant_id: ahmed-traders)  ──▶ ┐
Al-Shifa Pharma (tenant_id: alshifa-pharma) ──▶ ├──▶ Same DB
Karahi House   (tenant_id: karahi-house)   ──▶ ┘     RLS makes
                                                      them invisible
                                                      to each other
```

PostgreSQL RLS automatically filters every query by `tenant_id` from the JWT token. No cross-tenant data leak is possible, even with the API key.

**Roles:** `owner` → `manager` → `cashier` → `accountant` → `viewer`

<br/>

---

## ⚡ Quick Start

**1. Clone**
```bash
git clone https://github.com/YOUR_USERNAME/is_accounting.git
cd is_accounting
```

**2. Set Supabase credentials** in `lib/core/constants/app_constants.dart`
```dart
static const supabaseUrl     = 'https://xxxx.supabase.co';
static const supabaseAnonKey = 'eyJhbGc...';
```

**3. Run SQL** — paste `supabase/rls_setup.sql` into Supabase SQL Editor

**4. Generate Drift code** ← required after any DB change
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

**5. Run**
```bash
flutter run -d macos      # macOS
flutter run -d windows    # Windows
```

<br/>

---

## 📁 Project Structure

```
is_accounting/
├── lib/
│   ├── core/
│   │   ├── constants/         app_constants.dart  ← Supabase config HERE
│   │   ├── database/          app_database.dart   ← Drift schema (18 tables)
│   │   ├── router/            app_router.dart     ← GoRouter + guards
│   │   ├── theme/             app_theme.dart      ← Design system tokens
│   │   ├── licensing/         license_service.dart
│   │   ├── sync/              sync_engine.dart    ← Outbox pattern
│   │   └── utils/             error_handler, formatters
│   │
│   ├── features/
│   │   ├── auth/              license, login, setup wizard
│   │   ├── dashboard/         KPIs, charts, recent invoices
│   │   ├── pos/               keyboard-first POS terminal
│   │   ├── inventory/         products + stock management
│   │   ├── customers/         ledger + CNIC/NTN
│   │   ├── purchase/          [Phase 2] vendors + GRN
│   │   ├── accounts/          [Phase 2] GL + P&L
│   │   ├── reports/           [Phase 2] FBR reports
│   │   ├── settings/          business config + language
│   │   └── fbr/               fiscalization service
│   │
│   └── shared/
│       ├── providers/         Riverpod providers + cart state
│       └── widgets/           shell, common UI, loading overlay
│
├── supabase/
│   ├── rls_setup.sql          ← Run this in Supabase SQL Editor
│   └── functions/
│       ├── activate-license/  ← Deploy: supabase functions deploy
│       └── check-license/     ← Deploy: supabase functions deploy
│
├── SETUP_GUIDE.md             ← Step-by-step first-run guide
└── AI_CONTINUATION_SUMMARY.md ← Full context for AI pair-programming
```

<br/>

---

## 🎨 Design System

UI built on the **Inover Studio ERP** design language:

| Token | Value | Usage |
|---|---|---|
| Primary | `#0B6B43` Forest Emerald | Buttons, active states, sidebar |
| Gold | `#C49A4A` Royal Gold | Accents, table headers, badges |
| Surface | `#FFFEF9` Ivory | Cards, modals |
| Canvas | `#F4EEDD` Parchment | App background |
| Sidebar | `#0A1A11` Forest Black | Navigation |
| Body font | Inter | All UI text |
| Display font | Instrument Serif | Page headings (italic) |
| Mono font | JetBrains Mono | Numbers, IDs, amounts |

<br/>

---

## 🐛 Known Issues & Fixes

| Error | Cause | Fix |
|---|---|---|
| `Undefined name 'TenantsCompanion'` | build_runner not run | `dart run build_runner build` |
| `Invalid path 404` on login | Supabase URL not set | Set real URL in `app_constants.dart` |
| `permission denied for schema auth` | Old SQL tried to create auth functions | Use latest `rls_setup.sql` |
| macOS build fails with apostrophe | `PP's` in folder path | Rename folder — remove apostrophe |
| Login succeeds but no navigation | GoRouter stale state | Fixed in `app_router.dart` via `refreshListenable` |

<br/>

---

## 📄 License

```
MIT License — Copyright (c) 2026
```

Free to use, modify, and distribute. Attribution appreciated.

---

<div align="center">

**🇵🇰 Built in Pakistan, for Pakistan**

*94% of Pakistani SMEs have no software. This is for them.*

<br/>

<img src="https://capsule-render.vercel.app/api?type=waving&color=gradient&customColorList=6,12,20&height=120&section=footer" width="100%"/>

</div>
