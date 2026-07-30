import 'package:flutter_test/flutter_test.dart';
import 'package:tims_data_exporter/widgets/file_generator.dart';

void main() {
  test('Parse Alpha Knits Credit Note CR KSHS 43167.pdf text (Sample 4)', () async {
    const rawText = '''
P.O. Box 1  1 GPO  Nairobi, Kenya

Email: info@alphaknits.com OR sales@alphaknits.com

Website: www.alphaknits.com

Factor uru

alpha

Tel:  +254 20 3594711 / 2 / 3 / 4

Fax:  +254 20 2594710

Mob: +254 722 760063 / 733 771829

Manufacus f ualiy Kniwa, Scks, Yans, Baby Shawls,Kikis,T-Shis,

Pl-Shis & Caps. Embids & Scn Pins

To

EASYTEX LIMITED

Credit Note:

Orgnal

P.O BOX 151

NAIROBI

KENYA

PRINTING DATE:

16/06/26

CREDIT NOTE NO:

43167

DATE OF ISSUE:

16/06/26

ORDER NO:

Customer Ref. No.:

CUIN:

PIN

P051373112L

Item Code

HS Code

Item Description

Uom

Qty.

Unit Price

Vat%

Total Amount

SOY_DYED_ASST

POLYESTE DYED YAN ASST

KGMS

353.3

240.000

16

84,792.00

PAPE CONE

ASOTED  PAPE CONES

PCS

350

20.000

16

7,000.00

Sub Total

91,792.00 KES

EMAKS

Dscount

NB: PICE INCEAMENT

Based on A Invoce 23808.

E. & O. E

Net Total

91,792.00 KES

Tax

14,686.72 KES

Grand Total

106,478.72 KES

Prepared b:

Sagar Shah

- Accounts are nett and are strctl paable monthl or on demand. INTEEST wll be charged at 2.5% per month

on all overdue accounts. 15% Handlng charges on all goods returned after 7 das from date of recept.

- The above goods reman the property of Alpha Knts Ltd. Untl full pament s receved.

VAT REG NO. 1561U

P.I.N No. P659T

Page No.

1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 4);

    expect(model.tsNum, equals('43167'));
    expect(model.trType, equals(1)); // Credit Note
    expect(model.buyerPIN, equals('P051373112L'));
    expect(model.mwNum, equals('23808'));
    expect(model.totalAmount, closeTo(106478.72, 0.01));
    expect(model.vatAmountA, closeTo(14686.72, 0.01));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(2));

    final item1 = model.itemDetails!.first;
    expect(item1.itemCode, equals('SOY_DYED_ASST'));
    expect(item1.description, equals('POLYESTE DYED YAN ASST'));
    expect(item1.quantity, equals(353.3));
    expect(item1.unitPrice, closeTo(278.40, 0.01)); // 240 * 1.16
    expect(item1.itemAmount, closeTo(98358.72, 0.01)); // 84792 * 1.16

    final item2 = model.itemDetails!.last;
    expect(item2.itemCode, equals('PAPE CONE'));
    expect(item2.description, equals('ASOTED  PAPE CONES'));
    expect(item2.quantity, equals(350.0));
    expect(item2.unitPrice, closeTo(23.20, 0.01)); // 20 * 1.16
    expect(item2.itemAmount, closeTo(8120.0, 0.01)); // 7000 * 1.16
  });

  test('Parse Alpha Knits Credit Note CR KSHS 43167.pdf multiline extracted text', () async {
    const rawText = '''
P.O. Box 1  1 GPO  Nairobi, Kenya

Email: info@alphaknits.com OR sales@alphaknits.com

Website: www.alphaknits.com

Factor uru

alphace Due Date:

Tel:  +254 20 3594711 / 2 / 3 / 4

Fax:  +254 20 2594710

Mob: +254 722 760063 / 733 771829

Manufacus f ualiy Kniwa, Scks, Yans, Baby Shawls,Kikis,T-Shis,

Pl-Shis & Caps. Embids & Scn Pins

To690; 35650.

EASYTEX LIMITED

Credit Note:

Orgnale Date

P.O BOX 151

NAIROBI

KENYA-2026

PRINTING DATE:

16/06/26

CREDIT NOTE NO:

43167

DATE OF ISSUE:

16/06/26

ORDER NO:

Customer Ref. No.:

CUIN:

PIN

P051373112L

Item Code

HS Code

Item Description

Uom

Qty.

Unit Price

Vat%

Total Amount

SOY_DYED_ASST

POLYESTE DYED YAN ASST

KGMS

353.3

240.000

16

84,792.00

PAPE CONE

ASOTED  PAPE CONES

PCS

350

20.000

16

7,000.00

Sub Total

91,792.00 KES

EMAKS

Dscount

NB: PICE INCEAMENT

Based on A Invoce 23808.

E. & O. E

Net Total

91,792.00 KES

Tax

14,686.72 KES

Grand Total

106,478.72 KES

Prepared b:

Sagar Shah

VAT REG NO. 1561U

P.I.N No. P659T

Page No.

1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 4);

    expect(model.tsNum, equals('43167'));
    expect(model.trType, equals(1)); // Credit Note
    expect(model.buyerPIN, equals('P051373112L'));
    expect(model.mwNum, equals('23808'));
    expect(model.totalAmount, closeTo(106478.72, 0.01));
    expect(model.vatAmountA, closeTo(14686.72, 0.01));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(2));

    final item1 = model.itemDetails!.first;
    expect(item1.itemCode, equals('SOY_DYED_ASST'));
    expect(item1.description, equals('POLYESTE DYED YAN ASST'));
    expect(item1.quantity, equals(353.3));
    expect(item1.unitPrice, closeTo(278.40, 0.01));
    expect(item1.itemAmount, closeTo(98358.72, 0.01));

    final item2 = model.itemDetails!.last;
    expect(item2.itemCode, equals('PAPE CONE'));
    expect(item2.description, equals('ASOTED  PAPE CONES'));
    expect(item2.quantity, equals(350.0));
    expect(item2.unitPrice, closeTo(23.20, 0.01));
    expect(item2.itemAmount, closeTo(8120.0, 0.01));
  });

  test('Parse exact extracted text from user prompt for CR KSHS 43167.pdf', () async {
    const rawText = '''
P.O. Box 1  1 GPO  Nairobi, Kenya

Email: info@alphaknits.com OR sales@alphaknits.com

Website: www.alphaknits.com

Factor uru

alpha

Tel:  +254 20 3594711 / 2 / 3 / 4

Fax:  +254 20 2594710

Mob: +254 722 760063 / 733 771829

Manufacus f ualiy Kniwa, Scks, Yans, Baby Shawls,Kikis,T-Shis,

Pl-Shis & Caps. Embids & Scn Pins

To

EASYTEX LIMITED

Credit Note:

Orgnal

P.O BOX 151

NAIROBI

KENYA

PRINTING DATE:

16/06/26

CREDIT NOTE NO:

43167

DATE OF ISSUE:

16/06/26

ORDER NO:

Customer Ref. No.:

CUIN:

PIN

P051373112L

Item Code

HS Code

Item Description

Uom

Qty.

Unit Price

Vat%

Total Amount

SOY_DYED_ASST

POLYESTE DYED YAN ASST

KGMS

353.3

240.000

16

84,792.00

PAPE CONE

ASOTED  PAPE CONES

PCS

350

20.000

16

7,000.00

Sub Total

91,792.00 KES

EMAKS

Dscount

NB: PICE INCEAMENT

Based on A Invoce 23808.

E. & O. E

Net Total

91,792.00 KES

Tax

14,686.72 KES

Grand Total

106,478.72 KES

Prepared b:

Sagar Shah

- Accounts are nett and are strctl paable monthl or on demand. INTEEST wll be charged at 2.5% per month

on all overdue accounts. 15% Handlng charges on all goods returned after 7 das from date of recept.

- The above goods reman the propert of Alpha Knts Ltd. Untl full pament s receved.

VAT REG NO. 1561U

P.I.N No. P659T

Page No.

1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 5);

    expect(model.tsNum, equals('43167'));
    expect(model.trType, equals(1)); // Credit Note
    expect(model.buyerPIN, equals('P051373112L'));
    expect(model.mwNum, equals('23808'));
    expect(model.totalAmount, closeTo(106478.72, 0.01));
    expect(model.vatAmountA, closeTo(14686.72, 0.01));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(2));
  });

  test('Parse Alpha Knits Credit Note CR USD 43171.pdf text (USD 0% VAT)', () async {
    const rawText = '''
P.O. Box 1  1 GPO  Nairobi, Kenya
Email: info@alphaknits.com OR sales@alphaknits.com
Website: www.alphaknits.com
Factor uru
alpha
Tel:  +254 20 3594711 / 2 / 3 / 4
Fax:  +254 20 2594710
Mob: +254 722 760063 / 733 771829
Manufacus f ualiy Kniwa, Scks, Yans, Baby Shawls,Kikis,T-Shis,
Pl-Shis & Caps. Embids & Scn Pins
To
SIMBA APPAREL (EPZ) LTD
Credit Note:
Orgnal
P.O BOX 99139
1 MOMBASA
KENYA
PRINTING DATE:
27/07/26
CREDIT NOTE NO:
43171
DATE OF ISSUE:
27/07/26
ORDER NO:
Customer Ref. No.:
35650
CUIN:
PIN
P051544407Z
Item Code
HS Code
Item Description
Uom
Qty.
Unit Price
Vat%
Total Amount
0
0
LPO NO 908823
01773 _NAVY
0002.32
1X1 IB KNITTED 100% POLYESTE 5 PLY _N BLUE
KGS
116.55
10.350
1,206.29
Sub Total
1,206.29 USD
EMAKS
Dscount
WONG HS CODE
Based on A Invoce 23911.
E. & O. E
Net Total
1,206.29 USD
Tax
Grand Total
1,206.29 USD
Prepared b:
VAT REG NO. 1561U
P.I.N No. P659T
Page No.
1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 6, pdfPath: 'D:\\DTR TIMS\\alpha knits\\CR USD 43171.pdf');

    expect(model.tsNum, equals('43171'));
    expect(model.trType, equals(1)); // Credit Note
    expect(model.buyerPIN, equals('P051544407Z'));
    expect(model.mwNum, equals('23911'));
    expect(model.totalAmount, closeTo(1206.29, 0.01));
    expect(model.currency, equals('USD'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(1));
    expect(model.itemDetails!.first.itemCode, equals('01773 _NAVY'));
    expect(model.itemDetails!.first.quantity, equals(116.55));
    expect(model.itemDetails!.first.unitPrice, closeTo(10.35, 0.01));
    expect(model.itemDetails!.first.itemAmount, closeTo(1206.29, 0.01));
    expect(model.itemDetails!.first.taxCode, equals(2)); // Zero-rated
  });
}
