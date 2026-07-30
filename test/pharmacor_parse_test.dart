import 'package:flutter_test/flutter_test.dart';
import 'package:tims_data_exporter/widgets/file_generator.dart';

void main() {
  test('Parse Pharmacor 749.pdf text', () async {
    const rawText = '''
INVOICE

PHARMACOR LTD

OFFICE SUITS,4TH FLOOR BLOCK B,

PARKLAND ROAD,NAIROBI.

P.O BOX 14638  KENYA

Buyer

Ripple Pharmaceuticals Ltd

Swaminarayan Road/ Laxcon Court

Mezzanine Floor

P.O Box 10935 – 00100

Nairobi, Kenya

PIN: P051143479C

PIN

:

P051143479C

Invoice No.

749

Delivery Note

Supplier's Ref.

749

Buyer's Order No.

Despatch Document No.

Despatched through

Dated

14-May-2026

Mode/Terms of Payment

90 Days

Other Reference(s)

Dated

Delivery Note Date

Destination

Terms of Delivery

Sl

Description of Goods

Amount

per

Rate

Quantity

No.

1

CLAVAM BID 228.5 MG SYRUP 0039.11.30

1,836,000.00

Bottle

204.00

9,000 Bottle

(100.0000 CARTONS)

Batch:

25281809

4,840 Bottle

(53.7778 CARTONS)

Mfg Dt.

:

4-Oct-2025

Expiry:

31-Jul-2027

Batch:

25281815

4,160 Bottle

(46.2222 CARTONS)

Mfg Dt.

:

4-Dec-2025

Expiry:

31-Jul-2027

2

CLAVAM 1.2 GM INJ 0039.11.30

549,000.00

VIAL

366.00

1,500 VIAL

(7.8125 CARTONS)

Batch:

CAK25003ES

1,500 VIAL

(7.8125 CARTONS)

Mfg Dt.

:

6-Mar-2026

Expiry:

30-Nov-2027

3

CLAVAM 1GM TABS 0039.11.30

270,600.00

PACKET

451.00

600 PACKET

(6.0000 CARTONS)

Batch:

26280012

600 PACKET

(6.0000 CARTONS)

Mfg Dt.

:

25-Mar-2026

Expiry:

31-Dec-2027

4

CLAVAM 625 MG TABS 0039.11.30

1,752,000.00

PACKET

292.00

6,000 PACKET

(100.0000 CARTONS)

Batch:

25282157

710 PACKET

(11.8333 CARTONS)

Mfg Dt.

:

25-Mar-2026

Expiry:

30-Nov-2027

Batch:

25282158

5,290 PACKET

(88.1667 CARTONS)

Mfg Dt.

:

25-Mar-2026

Expiry:

30-Nov-2027

5

Normagina (3X10) 0039.11.30

150,000.00

PACKET

750.00

200 PACKET

(209.0909 CARTONS)

Batch:

ECZL06

200 PACKET

(209.0909 CARTONS)

Mfg Dt.

:

28-Nov-2025

Expiry:

30-Jul-2027

6

Novogermina Oral Susp 0039.11.30

1,750,000.00

Bottle

350.00

5,000 Bottle

(2.5000 CARTONS)

Batch:

BCS14125.

3,550 Bottle

(1.7750 CARTONS)

Mfg Dt.

:

8-May-2026

Expiry:

31-Oct-2027

Batch:

BCS14225

1,450 Bottle

(0.7250 CARTONS)

Mfg Dt.

:

14-May-2026

Expiry:

31-Oct-2027

continued ...

This is a Computer Generated Invoice



INVOICE(Page  2)

PHARMACOR LTD

OFFICE SUITS,4TH FLOOR BLOCK B,

PARKLAND ROAD,NAIROBI.

P.O BOX 14638  KENYA

Buyer

Ripple Pharmaceuticals Ltd

Swaminarayan Road/ Laxcon Court

Mezzanine Floor

P.O Box 10935 – 00100

Nairobi, Kenya

PIN: P051143479C

PIN

:

P051143479C

Invoice No.

749

Delivery Note

Supplier's Ref.

749

Buyer's Order No.

Despatch Document No.

Despatched through

Dated

14-May-2026

Mode/Terms of Payment

90 Days

Other Reference(s)

Dated

Delivery Note Date

Destination

Terms of Delivery

Sl

Description of Goods

Amount

per

Rate

Quantity

No.

7

ONDEM 4 MG/2ML INJ 0039.11.30

555,000.00

VIAL

1,850.00

300 VIAL

(2.5000 CARTONS)

Batch:

ODI-5002Z

65 VIAL

(0.5417 CARTONS)

Mfg Dt.

:

4-Dec-2025

Expiry:

31-Jul-2028

Batch:

ODI-5003Z

235 VIAL

(1.9583 CARTONS)

Mfg Dt.

:

4-Dec-2025

Expiry:

31-Aug-2028

8

ONDEM 8MG/4ML INJ 0039.11.30

840,000.00

VIAL

2,800.00

300 VIAL

(2.5000 CARTONS)

Batch:

ODIF-4001Z

300 VIAL

(2.5000 CARTONS)

Mfg Dt.

:

Jul-2024

Expiry:

30-Jun-2027

9

ONDEM MD TABS 8 MG(1 X 10) 0039.11.30

620,000.00

PACKET

620.00

1,000 PACKET

(1.2500 CARTONS)

Batch:

ONM25002ES

1,000 PACKET

(1.2500 CARTONS)

Mfg Dt.

:

Jul-2025

Expiry:

30-Jun-2027

10

PAN 40 MG INJ (VIAL) 0039.11.30

2,274,000.00

VIAL

379.00

6,000 VIAL

(50.0000 CARTONS)

Batch:

PNV25002ES

6,000 VIAL

(50.0000 CARTONS)

Mfg Dt.

:

5-May-2026

Expiry:

30-Sep-2027

11

PIPZO 4.5 GM INJ 0039.11.30

760,500.00

VIAL

507.00

1,500 VIAL

(7.8125 CARTONS)

Batch:

PZK25007ES

1,315 VIAL

(6.8490 CARTONS)

Mfg Dt.

:

4-Dec-2025

Expiry:

30-Sep-2028

Batch:

PZK25008ES

185 VIAL

(0.9635 CARTONS)

Mfg Dt.

:

Oct-2025

Expiry:

30-Sep-2028

12

SWICH 200 MG TABS 0039.11.30

168,900.00

PACKET

563.00

300 PACKET

(1.2500 CARTONS)

Batch:

SWK24002ES

300 PACKET

(1.2500 CARTONS)

Mfg Dt.

:

Dec-2024

Expiry:

30-Nov-2026

13

TAXIM-O 200MG TABS(1 X 10) 0039.11.30

810,000.00

PACKET

675.00

1,200 PACKET

(4.0000 CARTONS)

Batch:

TMK25001ES

1,200 PACKET

(4.0000 CARTONS)

Mfg Dt.

:

Feb-2025

Expiry:

31-Jan-2028

continued ...

This is a Computer Generated Invoice



INVOICE(Page  3)

PHARMACOR LTD

OFFICE SUITS,4TH FLOOR BLOCK B,

PARKLAND ROAD,NAIROBI.

P.O BOX 14638  KENYA

Buyer

Ripple Pharmaceuticals Ltd

Swaminarayan Road/ Laxcon Court

Mezzanine Floor

P.O Box 10935 – 00100

Nairobi, Kenya

PIN: P051143479C

PIN

:

P051143479C

Invoice No.

749

Delivery Note

Supplier's Ref.

749

Buyer's Order No.

Despatch Document No.

Despatched through

Dated

14-May-2026

Mode/Terms of Payment

90 Days

Other Reference(s)

Dated

Delivery Note Date

Destination

Terms of Delivery

Sl

Description of Goods

Amount

per

Rate

Quantity

No.

14

ZOCEF 750 MG INJ 0039.11.30

283,200.00

VIAL

236.00

1,200 VIAL

(3.0000 CARTONS)

Batch:

5003007

1,200 VIAL

(3.0000 CARTONS)

Mfg Dt.

:

20-Dec-2025

Expiry:

31-Oct-2027

15

Rifakem 550mg Tabs 10's 0039.11.30

261,300.00

PACKET

871.00

300 PACKET

(1.0000 CARTONS)

Batch:

ST25-1372

300 PACKET

(1.0000 CARTONS)

Mfg Dt.

:

May-2025

Expiry:

30-Apr-2027

16

Nuloc-IV 40mg 10ml 0039.11.30

2,232,000.00

VIAL

186.00

12,000 VIAL

(100.0000 CARTONS)

Batch:

EPI25002ED

12,000 VIAL

(100.0000 CARTONS)

Mfg Dt.

:

Dec-2024

Expiry:

30-Nov-2027

17

Ondem Oral Solution USP 30ml 0039.11.30

234,000.00

Bottle

390.00

600 Bottle

(5.0000 CARTONS)

Batch:

ODS25002E

600 Bottle

(5.0000 CARTONS)

Mfg Dt.

:

Dec-2025

Expiry:

30-Nov-2027

18

UBIOSIS CAPS 30'S

15,000.00

PACKET

150.00

100 PACKET

Batch:

ECZH02

100 PACKET

Mfg Dt.

:

21-Oct-2025

Expiry:

31-Jul-2027

19

ZOCEF 500 MG TABS 0039.11.30

1,308,480.00

PACKET

282.00

4,640 PACKET

(19.3333 CARTONS)

Batch:

ZOF25016ES

4,640 PACKET

(19.3333 CARTONS)

Mfg Dt.

:

4-May-2026

Expiry:

30-Nov-2027

Total

KSh16,669,980.00

Amount Chargeable (in words)

Kenyan Shilling Sixteen Million Six Hundred Sixty Nine

Thousand Nine Hundred Eighty Only

Company's VAT No.

:

P051389037L

Company's PIN

:

P051389037L

Declaration

We declare that this invoice shows the actual price of the

goods described and that all particulars are true and correct.

E. & O.E

for PHARMACOR LTD

Authorised Signatory

This is a Computer Generated Invoice
''';

    final dataModel = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 1);
    expect(dataModel.tsNum, equals('749'));
    expect(dataModel.buyerPIN, equals('P051143479C'));
    expect(dataModel.totalAmount, equals(16669980.0));
    expect(dataModel.itemDetails, isNotNull);
    expect(dataModel.itemDetails!.length, equals(19));

    // Verify HS code / item code parsing and description cleaning
    expect(dataModel.itemDetails![0].description, equals('CLAVAM BID 228.5 MG SYRUP'));
    expect(dataModel.itemDetails![0].itemCode, equals('0039.11.30'));

    expect(dataModel.itemDetails![17].description, equals("UBIOSIS CAPS 30'S"));
    expect(dataModel.itemDetails![17].itemCode, isNull);

    expect(dataModel.itemDetails![18].description, equals('ZOCEF 500 MG TABS'));
    expect(dataModel.itemDetails![18].itemCode, equals('0039.11.30'));
  });

  test('Parse Pharmacor 221.pdf Credit Note text', () async {
    const rawText = '''
Credit Note

PHARMACOR LTD

OFFICE SUITS,4TH FLOOR BLOCK B,

PARKLAND ROAD,NAIROBI.

P.O BOX 14638  KENYA

Party :

Ripple Pharmaceuticals Ltd



Swaminarayan Road/ Laxcon Court

Mezzanine Floor

P.O Box 10935 – 00100

Nairobi, Kenya

PIN: P051143479C

Credit Note No.

221

Buyer's Ref.

INV647  dt. 14-Jul-2025

Buyer's Order No.

Despatch Document No.

Despatched through

Dated

31-Jul-2025

Mode/Terms of Payment

90 Days

Other Reference(s)

Dated

Destination

Terms of Delivery

Sl

Description of Goods

Amount

per

Rate

Quantity

No.

1

CLAVAM 625 MG TABS 0039.11.30

2,330,160.00

PACKET

292.00

7,980 PACKET

(133.0000 CARTONS)

Batch:

25280998

7,980 PACKET

(133.0000 CARTONS)

Mfg Dt.

:

11-Jul-2025

Expiry:

30-Apr-2027

2

Ondem MD 4 (1*10) Tabs 0039.11.30

3,360,000.00

PCS

700.00

4,800 PCS

Batch:

OMK25001ES

4,800 PCS

Mfg Dt.

:

11-Jul-2025

Expiry:

30-Apr-2027

3

CLAVAM 625 MG TABS 0039.11.30

2,330,160.00

PACKET

292.00

7,980 PACKET

(133.0000 CARTONS)

Batch:

25280997

7,980 PACKET

(133.0000 CARTONS)

Mfg Dt.

:

11-Jul-2025

Expiry:

30-Apr-2027

Total

KSh8,020,320.00

Amount Chargeable (in words)

Kenyan Shilling Eight Million Twenty Thousand Three

Hundred Twenty Only

Company's VAT No.

:

P051389037L

Company's PIN

:

P051389037L

E. & O.E

for PHARMACOR LTD

Authorised Signatory

This is a Computer Generated Document
''';

    final dataModel = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 1);
    expect(dataModel.tsNum, equals('221'));
    expect(dataModel.buyerPIN, equals('P051143479C'));
    expect(dataModel.totalAmount, equals(8020320.0));
    expect(dataModel.trType, equals(1)); // Credit note
    expect(dataModel.mwNum, equals('INV647'));
    expect(dataModel.itemDetails, isNotNull);
    expect(dataModel.itemDetails!.length, equals(3));

    expect(dataModel.itemDetails![0].description, equals('CLAVAM 625 MG TABS'));
    expect(dataModel.itemDetails![0].itemCode, equals('0039.11.30'));
    expect(dataModel.itemDetails![0].quantity, equals(7980.0));
    expect(dataModel.itemDetails![0].unitPrice, equals(292.0));

    expect(dataModel.itemDetails![1].description, equals('Ondem MD 4 (1*10) Tabs'));
    expect(dataModel.itemDetails![1].itemCode, equals('0039.11.30'));
    expect(dataModel.itemDetails![1].quantity, equals(4800.0));
    expect(dataModel.itemDetails![1].unitPrice, equals(700.0));
  });
}
