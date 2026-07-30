import 'package:flutter_test/flutter_test.dart';
import 'package:tims_data_exporter/widgets/file_generator.dart';

void main() {
  test('Parse Marketpower 160171.pdf text', () async {
    const rawText = '''
O
:
0722 202 321
/
0733 622 141
T
:  (+
254 20
)
374 1569
-
72
Odyssey Building
4
th Floor
,
84
Muthithi Road
,
Westlands
.
P
.
O Box
43758
-
00100
NRB
,
Kenya
Email
:
theteam
@
marketpower
.
co
.
ke
Website
:
www
.
marketpower
.
co
.
ke
PIN
:
P
051096853
K
VAT REG NO
:
0023525
L
INVOICE
Invoice No
.:
RAMCO PRINTING WORKS
02-Jul-2026
27750
-
506
Attn
:
160171
PIN
:
P051102301X
LPO No
:
Terms
:
Payment Due By
:
60 DAYS
31-Aug-2026
Job No
:
DNote No
:
Designer
:
Rebecca Ireri
Description
Quantity
Unit Price
Amount
HS Codes
VAT
Rent for the month of
01
/
07
/
2026
to
31
/
07
/
2026
1200000.00
1,200,000.00
16
Rent for the month of 01/07/2026 to 31/07/2026
1
THANK YOU FOR YOUR BUSINESS
M
-
PESA PAYBILL NUMBER
347500
1,392,000.00
192,000.00
Total
VAT
Grand Total
E
&
OE
1,200,000.00
Interest
@
3
%
per month will be charged on all overdue accounts
.
PLEASE MAKE ALL PAYMENTS TO
:
MARKETPOWER INTERNATIONAL LTD A
/
C KCB BANK KENYA LTD
.
A
/
C Name
:
Marketpower International Limited
.
Bank
:
Kenya Commercial Bank
Branch
:
Industrial Area
A
/
C No
:
1235855953
Please note that we will not be responsible for any cheques not issued as above
.
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 1);

    expect(model.tsNum, equals('160171'));
    expect(model.buyerPIN, equals('P051102301X'));
    expect(model.totalAmount, equals(1392000.0));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(1));
    expect(model.itemDetails!.first.description, contains('Rent for the month of 01/07/2026 to 31/07/2026'));
    expect(model.itemDetails!.first.itemAmount, equals(1392000.0));
    expect(model.itemDetails!.first.taxCode, equals(1));
    expect(model.itemDetails!.first.quantity, equals(1.0));
  });
}
