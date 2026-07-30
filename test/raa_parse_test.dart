import 'package:flutter_test/flutter_test.dart';
import 'package:tims_data_exporter/widgets/file_generator.dart';

void main() {
  test('Parse RAA Limited TAX INVOICE 619047.pdf text', () async {
    const rawText = '''
Page 1 of 1

RAA LIMITED

Warehouse 1A, Ideal Ceramics Compound,

ICD Road, Nairobi KenyaNaivas Ltd - T-SQUARE BURU BURU

TAX INVOICE

Contact Numbers : 0734756071/0722202971

Tax

Ck. BxItem DescriptionAmountQtyDisc%UnitPrice

P051151358Q

sales@raalimited.com

Hs CodeN0013-39

T-Square Mall Buruburu

Contact:Karanja

Route:Eastlands DandoraPIN:P051123223GDate:27-07-2026

Invoice Number:619047P042746459-1Order Number:

Payment IPR-000593414William WambuguSales Rep:

Delivery Instructions:

Terms:30 Days

Pay Bill: 982800,A/C: 3000022286Eastlands DandoraCustomer Service Tel:0715 181818 Email: customerservice@raalimited.com

1

0039.11.55515.00515.00Mentho Plus White Balm 9mlDOZPlease ensure you recieve the correct quantity and description of goods at the time of delivery, No queries will be entertained later.Goods once sold are not returnable.

Penalty will be charged at 3% per month on overdue accounts.E. & O. E.Above goods remain property of RAA LTD until payment is received

CASH SHOULD NOT BE PAID TO SALES REPRESENTATIVES OR ANY OTHER EMPLOYEE

PAYMENTS SHOULD ONLY BE MADE TO THE PAYBILL OR VIA CHEQUE

Printed On:

Received By:

ID No:

27/07/2026 12:33:00

Prepared By:

YasminAuthorised By:

WE HAVE RECEIVED THE ABOVE GOODS IN GOOD ORDER AND CONDITIONSIGNATURE & CO's OFFICIAL RUBBER STAMPSub Total (Excl)VATTotal (Incl)

515.000.00515.00

Designation:Time:Signature:

Date:

Page 1 of 1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 1);

    expect(model.tsNum, equals('619047'));
    expect(model.trType, equals(0)); // Invoice
    expect(model.buyerPIN, equals('P051123223G'));
    expect(model.totalAmount, equals(515.00));
    expect(model.vatAmountA, equals(0.00));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(1));

    final item = model.itemDetails!.first;
    expect(item.description, equals('Mentho Plus White Balm 9ml'));
    expect(item.itemCode, equals('0039.11.55'));
    expect(item.quantity, equals(1.0));
    expect(item.unitPrice, equals(515.00));
    expect(item.itemAmount, equals(515.00));
  });

  test('Parse RAA Limited TAX INVOICE 619048.pdf text (No inline HS Code on item line)', () async {
    const rawText = '''
Page 1 of 1

RAA LIMITED

Warehouse 1A, Ideal Ceramics Compound,

ICD Road, Nairobi KenyaNaivas Ltd -  RIRONI

TAX INVOICE

Contact Numbers : 0734756071/0722202971

Tax

Ck. BxItem DescriptionAmountQtyDisc%UnitPrice

73.23

P051151358Q

sales@raalimited.com

Hs CodeN0013-119

Rironi Tilisi Development Nairobi-Nakuru

Contact:Peter Bsc

Route:LimuruPIN:P051123223GDate:27-07-2026

Invoice Number:619048P042719581-1Order Number:

Payment IPR-000562566William WambuguSales Rep:

Delivery Instructions:

Terms:30 Days

Pay Bill: 982800,A/C: 3000022286LimuruCustomer Service Tel:0715 181818 Email: customerservice@raalimited.com

1

530.89530.89Raa Agarbati Hexa pack CitronelDOZPlease ensure you recieve the correct quantity and description of goods at the time of delivery, No queries will be entertained later.Goods once sold are not returnable.

Penalty will be charged at 3% per month on overdue accounts.E. & O. E.Above goods remain property of RAA LTD until payment is received

CASH SHOULD NOT BE PAID TO SALES REPRESENTATIVES OR ANY OTHER EMPLOYEE

PAYMENTS SHOULD ONLY BE MADE TO THE PAYBILL OR VIA CHEQUE

Printed On:

Received By:

ID No:

27/07/2026 12:36:20

Prepared By:

YasminAuthorised By:

WE HAVE RECEIVED THE ABOVE GOODS IN GOOD ORDER AND CONDITIONSIGNATURE & CO's OFFICIAL RUBBER STAMPSub Total (Excl)VATTotal (Incl)

457.6673.23530.89

Designation:Time:Signature:

Date:

Page 1 of 1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 2);

    expect(model.tsNum, equals('619048'));
    expect(model.trType, equals(0)); // Invoice
    expect(model.buyerPIN, equals('P051123223G'));
    expect(model.totalAmount, equals(530.89));
    expect(model.vatAmountA, equals(73.23));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(1));

    final item = model.itemDetails!.first;
    expect(item.description, equals('Raa Agarbati Hexa pack Citronel'));
    expect(item.itemCode, isNull);
    expect(item.quantity, equals(1.0));
    expect(item.unitPrice, equals(530.89));
    expect(item.itemAmount, equals(530.89));
  });

  test('Parse RAA Limited TAX INVOICE 619041.pdf text (Multi-item multi-quantity)', () async {
    const rawText = '''
Page 1 of 1

RAA LIMITED

Warehouse 1A, Ideal Ceramics Compound,

ICD Road, Nairobi KenyaQuickmart Ltd - NYALI

TAX INVOICE

Contact Numbers : 0734756071/0722202971

Tax

Ck. BxItem DescriptionAmountQtyDisc%UnitPrice

173.79

P051151358Q

sales@raalimited.com

Hs CodeQ0004-60

Krish Plaza

Contact:Bosire,Newton

Route:Mombasa CBDPIN:P051188806DDate:27-07-2026

Invoice Number:619041OSTâ00050032Order Number:

Payment Sarah MbucheSales Rep:

Delivery Instructions:

Terms:45 Days

Pay Bill: 982800,A/C: 3000022286Mombasa CBDCustomer Service Tel:0715 181818 Email: customerservice@raalimited.com

1

1,260.001,260.00NFP Cream 50mlDOZ

1

1,848.001,848.00NFP Cream 80mlDOZ

12

62.05744.58Parle Hide & Seek Black Bourbon Van 100gPKT

1

511.20511.20Raa Natural AwaazDOZ

1

511.20511.20Raa Agarbati Hexa pack lavenderDOZ

1

511.20511.20Raa Agarbati Hexa pack roseDOZ

1

511.20511.20Raa Agarbati Hexa pack sandalDOZ

1

511.20511.20Raa Agarbati Hexa pack cinnamonDOZPlease ensure you recieve the correct quantity and description of goods at the time of delivery, No queries will be entertained later.Goods once sold are not returnable.

Penalty will be charged at 3% per month on overdue accounts.E. & O. E.Above goods remain property of RAA LTD until payment is received

CASH SHOULD NOT BE PAID TO SALES REPRESENTATIVES OR ANY OTHER EMPLOYEE

PAYMENTS SHOULD ONLY BE MADE TO THE PAYBILL OR VIA CHEQUE

Printed On:

Received By:

ID No:

27/07/2026 17:33:56

Prepared By:

MariyaAuthorised By:

WE HAVE RECEIVED THE ABOVE GOODS IN GOOD ORDER AND CONDITIONSIGNATURE & CO's OFFICIAL RUBBER STAMPSub Total (Excl)VATTotal (Incl)

5,524.64883.946,408.58

Designation:Time:Signature:

Date:

Page 1 of 1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 3);

    expect(model.tsNum, equals('619041'));
    expect(model.trType, equals(0)); // Invoice
    expect(model.buyerPIN, equals('P051188806D'));
    expect(model.totalAmount, equals(6408.58));
    expect(model.vatAmountA, equals(883.94));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(8));

    final item3 = model.itemDetails![2];
    expect(item3.description, equals('Parle Hide & Seek Black Bourbon Van 100g'));
    expect(item3.quantity, equals(12.0));
    expect(item3.itemAmount, equals(744.58));
    expect(item3.unitPrice, closeTo(62.04833, 0.001));

    // Verify sum of item amounts equals total amount
    final sumItems = model.itemDetails!.fold(0.0, (sum, item) => sum + item.itemAmount);
    expect(sumItems, closeTo(6408.58, 0.01));
  });

  test('Parse RAA Limited Credit Note CRN84135.pdf text', () async {
    const rawText = '''
Page 1 of 1
RAA LIMITED
Warehouse 1A, Ideal Ceramics Compound,
ICD Road, Nairobi Kenya
Genesis Malimali
Contact Numbers : 0734756071/0722202971
Tax
Ck. BxItem DescriptionAmount
Qty
Disc%
UnitPrice
P051151358Q
sales@raalimited.com
Hs Code
MSAG0013
Bondeni
Contact:Kamunye
Route:Bondeni
PIN:A012970825U
Date:19-11-2025
Invoice Number:
CRN84135
GRN/188/595460/SHORT EXPIRY
Order Number:
Payment
Elvis Mbwau
Sales Rep:
Delivery Instructions:
Terms:Current
Pay Bill: 982800,A/C: 3000022286
Bondeni
CREDIT NOTE
Customer Service Tel:0715 181818 Email: customerservice@raalimited.com
5
Price Difference/MPB White Balm 432x4ml
1,640.008,200.00
Printed On:
Received By:
ID No:
07-Jan-26 3:06:05 PM
Prepared By:
Branice
Authorised By:
WE HAVE RECEIVED THE ABOVE GOODS IN GOOD ORDER AND CONDITION
SIGNATURE & CO's OFFICIAL RUBBER STAMP
Sub Total (Excl)
VAT
Total (Incl)
8,200.00
0.00
8,200.00
Designation:
Time:
Signature:
Date:
Page 1 of 1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 4, pdfPath: 'D:\\DTR TIMS\\RAA\\CRN84135.pdf');

    expect(model.tsNum, equals('84135'));
    expect(model.trType, equals(1)); // Credit Note
    expect(model.buyerPIN, equals('A012970825U'));
    expect(model.totalAmount, equals(8200.00));
    expect(model.vatAmountA, equals(0.00));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(1));

    final item = model.itemDetails!.first;
    expect(item.description, equals('Price Difference/MPB White Balm 432x4ml'));
    expect(item.itemCode, isNull);
    expect(item.quantity, equals(5.0));
    expect(item.unitPrice, equals(1640.00));
    expect(item.itemAmount, equals(8200.00));
  });

  test('Parse RAA Limited Credit Note CRN87647.pdf text (Printed On attached to amount line)', () async {
    const rawText = '''
Page 1 of 1
RAA LIMITED
Warehouse 1A, Ideal Ceramics Compound,
ICD Road, Nairobi KenyaRoadMap Group LimitedContact Numbers : 0734756071/0722202971
Tax
Ck. BxItem DescriptionAmountQtyDisc%UnitPrice
23.72
P051151358Q
sales@raalimited.com
Hs CodeR0010
Timau
Contact:Wairimu
Route:Mountain 1PIN:P051537967ZDate:23-07-2026
Invoice Number:CRN87647GRN54053/104180/BOGOFOrder Number:
Payment Dennis MwakaSales Rep:
Delivery Instructions:
Terms:30 Days
Pay Bill: 982800,A/C: 3000022286Mountain 1
CREDIT NOTE
Customer Service Tel:0715 181818 Email: customerservice@raalimited.com
4
Price Difference/Parle Bakesmith Marie Biscs 150g
43.00172.00Printed On:
Received By:
ID No:
25/07/2026 13:46:18
Prepared By:
CharlesAuthorised By:
WE HAVE RECEIVED THE ABOVE GOODS IN GOOD ORDER AND CONDITIONSIGNATURE & CO's OFFICIAL RUBBER STAMPSub Total (Excl)VATTotal (Incl)
148.2823.72172.00
Designation:Time:Signature:
Date:
Page 1 of 1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 5, pdfPath: 'D:\\DTR TIMS\\RAA\\CRN87647.pdf');

    expect(model.tsNum, equals('87647'));
    expect(model.trType, equals(1)); // Credit Note
    expect(model.buyerPIN, equals('P051537967Z'));
    expect(model.totalAmount, equals(172.00));
    expect(model.vatAmountA, equals(23.72));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(1));

    final item = model.itemDetails!.first;
    expect(item.description, equals('Price Difference/Parle Bakesmith Marie Biscs 150g'));
    expect(item.itemCode, isNull);
    expect(item.quantity, equals(4.0));
    expect(item.unitPrice, equals(43.00));
    expect(item.itemAmount, equals(172.00));
  });

  test('Parse RAA Limited Credit Note CRN87650.pdf text (CTNPrinted On attached to amount line)', () async {
    const rawText = '''
Page 1 of 1
RAA LIMITED
Warehouse 1A, Ideal Ceramics Compound,
ICD Road, Nairobi KenyaKware Mart SupermarketContact Numbers : 0734756071/0722202971
Tax
Ck. BxItem DescriptionAmountQtyDisc%UnitPrice
296.53
P051151358Q
sales@raalimited.com
Hs CodeK0285
Rongai Sokoni
Contact:Macharia
Route:RongaiPIN:P051190517JDate:23-07-2026
Invoice Number:CRN87650
618132/EXPIRY DATE ISSUE
Order Number:
Payment Irene MogeniSales Rep:
Delivery Instructions:
Terms:30 Days
Pay Bill: 982800,A/C: 3000022286Rongai
CREDIT NOTE
Customer Service Tel:0715 181818 Email: customerservice@raalimited.com
1
Parle Bakesmith Marie Biscs 150g
2,149.852,149.85CTNPrinted On:
Received By:
ID No:
25/07/2026 15:10:32
Prepared By:
CharlesAuthorised By:
WE HAVE RECEIVED THE ABOVE GOODS IN GOOD ORDER AND CONDITIONSIGNATURE & CO's OFFICIAL RUBBER STAMPSub Total (Excl)VATTotal (Incl)
1,853.32296.532,149.85
Designation:Time:Signature:
Date:
Page 1 of 1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 6, pdfPath: 'D:\\DTR TIMS\\RAA\\CRN87650.pdf');

    expect(model.tsNum, equals('87650'));
    expect(model.trType, equals(1)); // Credit Note
    expect(model.buyerPIN, equals('P051190517J'));
    expect(model.totalAmount, equals(2149.85));
    expect(model.vatAmountA, equals(296.53));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(1));

    final item = model.itemDetails!.first;
    expect(item.description, equals('Parle Bakesmith Marie Biscs 150g'));
    expect(item.itemCode, isNull);
    expect(item.quantity, equals(1.0));
    expect(item.unitPrice, equals(2149.85));
    expect(item.itemAmount, equals(2149.85));
  });

  test('Parse RAA Limited TAX INVOICE 619057.pdf text (Multiline description after amount line)', () async {
    const rawText = '''
Page 1 of 1
RAA LIMITED
Warehouse 1A, Ideal Ceramics Compound,
ICD Road, Nairobi KenyaNaivas Ltd - NGONG II
TAX INVOICE
Contact Numbers : 0734756071/0722202971
Tax
Ck. BxItem DescriptionAmountQtyDisc%UnitPrice
73.23
P051151358Q
sales@raalimited.com
Hs CodeN0013-62
Ngong Cbd
Contact:Antony
Route:NgongPIN:P051123223GDate:27-07-2026
Invoice Number:619057P042772105-1Order Number:
Payment IPR-000607834William WambuguSales Rep:
Delivery Instructions:
Terms:30 Days
Pay Bill: 982800,A/C: 3000022286NgongCustomer Service Tel:0715 181818 Email: customerservice@raalimited.com
1
530.89530.89Raa Agarbati Hexa pack appleDOZ
1
530.89530.89Raa Agarbati Hexa pack cherryDOZ
1
530.89530.89Raa Agarbati Hexa pack cinnamonDOZ
1
530.89530.89Raa Agarbati Hexa pack CitronelDOZ
1
530.89530.89Raa Agarbati Hexa pack EucalyptusDOZ
2
1,752.013,504.01
Virani Curry Powder 100g
DOZ
1
4,730.404,730.40
Virani Curry Powder 500g
DOZPlease ensure you recieve the correct quantity and description of goods at the time of delivery, No queries will be entertained later.Goods once sold are not returnable.     
Penalty will be charged at 3% per month on overdue accounts.E. & O. E.Above goods remain property of RAA LTD until payment is received
CASH SHOULD NOT BE PAID TO SALES REPRESENTATIVES OR ANY OTHER EMPLOYEE
PAYMENTS SHOULD ONLY BE MADE TO THE PAYBILL OR VIA CHEQUE
Printed On:
Received By:
ID No:
27/07/2026 12:55:15
Prepared By:
YasminAuthorised By:
WE HAVE RECEIVED THE ABOVE GOODS IN GOOD ORDER AND CONDITIONSIGNATURE & CO's OFFICIAL RUBBER STAMPSub Total (Excl)VATTotal (Incl)
9,386.93
1,501.9310,888.86
Designation:Time:Signature:
Date:
Page 1 of 1
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 7, pdfPath: 'D:\\DTR TIMS\\RAA\\619057.pdf');

    expect(model.tsNum, equals('619057'));
    expect(model.trType, equals(0)); // Invoice
    expect(model.buyerPIN, equals('P051123223G'));
    expect(model.totalAmount, equals(10888.86));
    expect(model.vatAmountA, equals(1501.93));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(7));

    final item6 = model.itemDetails![5];
    expect(item6.description, equals('Virani Curry Powder 100g'));
    expect(item6.quantity, equals(2.0));
    expect(item6.unitPrice, closeTo(1752.01, 0.01));
    expect(item6.itemAmount, equals(3504.01));

    final item7 = model.itemDetails![6];
    expect(item7.description, equals('Virani Curry Powder 500g'));
    expect(item7.quantity, equals(1.0));
    expect(item7.unitPrice, equals(4730.40));
    expect(item7.itemAmount, equals(4730.40));
  });

  test('Parse RAA Limited TAX INVOICE 619208 (Numeric Order Number 1001130007345)', () async {
    const rawText = '''
Page 1 of 1

RAA LIMITED

Warehouse 1A, Ideal Ceramics Compound,

ICD Road, Nairobi KenyaChandarana S.Markets Ltd - Watamu Branch

TAX INVOICE

Contact Numbers : 0734756071/0722202971

Tax

Ck. BxItem DescriptionAmountQtyDisc%UnitPrice

521.38

P051151358Q

sales@raalimited.com

Hs CodeC0015-35

Blue Moon Shopping centre,Watamu

Contact:Eunice

Route:Kilifi/ WetamuPIN:P000601772PDate:28-07-2026

Invoice Number:6192081001130007345Order Number:

Payment Sarah MbucheSales Rep:

Delivery Instructions:

Terms:30Days

Pay Bill: 982800,A/C: 3000022286Kilifi/ WetamuCustomer Service Tel:0715 181818 Email: customerservice@raalimited.com

0783919062

6

630.003,779.98

Max Protein7 Grain Granola Nuts&Seeds Hazelnut360g

PCS

6

630.003,779.98

Max Protein7 Grains Granola Dark Choc Hazelnut360g

PCS

1

1,671.591,671.59Max Protein Millet Wafer 40g StrawBerry TruffleDOZ

1

1,671.591,671.59Max Protein Millet Wafer 40g Choco TemptationDOZ

Please ensure you recieve the correct quantity and description of goods at the time of delivery, No queries will be entertained later.Goods once sold are not returnable.        

Penalty will be charged at 3% per month on overdue accounts.E. & O. E.Above goods remain property of RAA LTD until payment is received

CASH SHOULD NOT BE PAID TO SALES REPRESENTATIVES OR ANY OTHER EMPLOYEE

PAYMENTS SHOULD ONLY BE MADE TO THE PAYBILL OR VIA CHEQUE

Printed On:

Received By:

ID No:

7/28/2026 4:31:44 PM

Prepared By:

MariyaAuthorised By:

WE HAVE RECEIVED THE ABOVE GOODS IN GOOD ORDER AND CONDITIONSIGNATURE & CO's OFFICIAL RUBBER STAMPSub Total (Excl)VATTotal (Incl)

9,399.26

1,503.8810,903.14

Designation:Time:Signature:

Date:

Page 1 of 1187.99Amount to deduct As 2%

Withholding VAT On Vatable Items

If you are a Withholding VAT Agent
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 8, pdfPath: 'D:\\DTR TIMS\\RAA\\6192081001130007345.pdf');

    expect(model.tsNum, equals('619208'));
    expect(model.trType, equals(0)); // Invoice
    expect(model.buyerPIN, equals('P000601772P'));
    expect(model.totalAmount, equals(10903.14));
    expect(model.vatAmountA, equals(1503.88));
    expect(model.currency, equals('KES'));
  });
}

