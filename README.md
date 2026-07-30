# TIM's Data Exporter

**TIM's Data Exporter** is a Flutter desktop and multi-platform application developed by **Quantyx Labs** for automating tax transaction data extraction, fiscal compliance processing, and tax invoice generation. It is designed to process sales invoices and credit notes, interface with Tax Invoice Management System (TIMS) / ETR databases, generate QR codes, and output compliant tax documents.

---

## 🚀 Key Features

- **Automated PDF Parsing & Extraction**
  - Parses PDF invoices and credit notes from various vendor templates (e.g., Sleek Kenya, Alpha Knits, Pharmacor, RAA).
  - Automatically extracts transaction numbers (`TsNum`), Buyer PIN, line items, quantities, item discounts, currency, net total, and VAT allocations.

- **TIMS / ETR Fiscal Database Integration**
  - Connects to local SQLite databases (e.g., `FbTransaction.db`).
  - Queries Control Unit Invoice Number (`CUIN` / `MwNum`), Control Unit Serial Number (`CUSN`), date timestamps, and official QR code payloads.

- **Dynamic QR Code & Fiscal Details Stamping**
  - Generates KRA-compliant QR codes on the fly.
  - Stamps QR codes, `Date`, `CUIN`, and `CUSN` directly onto generated Tax PDF documents (`_TAX.pdf`).
  - Customizable QR placement (Bottom-Right, Bottom-Left, Custom X/Y coordinates) and layout formats (*beside* vs. *below* text).

- **Real-Time Directory Watcher & Batch Processing**
  - Automatically monitors input directories (e.g., `C:\DTR APP\invoice`) for incoming PDF documents and processes them in real-time.
  - Supports manual batch selection and processing of multiple PDF files simultaneously.

- **Credit Notes & Multi-Currency Support**
  - Identifies credit note transactions (`TrType == 1`) and links them with relevant invoice Control Unit numbers.
  - Offers foreign currency conversion prompts for non-KES transactions to automatically compute KES equivalents.

- **Sales Analytics & Fiscal Reports**
  - Integrated dashboard with sales revenue charts and daily sales performance powered by `fl_chart`.
  - Comprehensive tax summary breakdown (VAT A, B, C, D, E).
  - Customer insights and advanced table filtering/search capabilities.

- **File & Directory Management**
  - Automatically organizes outputs into `tax_invoices`, `text files`, `processed`, `duplicate`, and `ticket` folders.

---

## 🛠️ Built With

- **Framework**: [Flutter](https://flutter.dev/) (Dart ^3.6.0)
- **PDF Generation & Editing**: `syncfusion_flutter_pdf`
- **Database**: `sqflite_common_ffi` / SQLite
- **Charts & Visualization**: `fl_chart`
- **QR Code Generation**: `qr` & `image`
- **Packaging / Installer**: `msix` & Inno Setup (`installer_script.iss`)

---

## 📁 Directory Structure Overview

```text
C:\DTR APP\
 ├── invoice\          # Input directory (watched for incoming PDFs)
 ├── processed\        # Archived original PDFs after processing
 ├── duplicate\        # Duplicates directory
 ├── tax_invoices\     # Stamped Tax PDF output files (*_TAX.pdf)
 └── text files\       # Generated text export files
```

---

## 💻 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.27.0 or higher)
- [Dart SDK](https://dart.dev/get-sdk) (^3.6.0)

### Installation & Local Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Pearl-Techno/TIMS-Data-Exporter.git
   cd TIMS-Data-Exporter
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the desktop app:**
   ```bash
   flutter run -d windows
   ```

4. **Build MSIX Installer (Windows):**
   ```bash
   flutter pub run msix:create
   ```

---

## 📄 License & Publisher

Developed by **Quantyx Labs**, Nairobi, Kenya.  
*All rights reserved.*
