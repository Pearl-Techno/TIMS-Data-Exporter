import 'package:flutter_test/flutter_test.dart';
import 'package:tims_data_exporter/widgets/file_generator.dart';

void main() {
  test('Parse Alpha Knits KSH INV 23918.pdf text (Sample 1)', () async {
    const rawText = '''
 P.O. Box 47018 - 00100 GPO - Nairobi, Kenya

Email: info@alphaknits.com OR sales@alphaknits.com

Website: www.alphaknits.com

Factory (Ruiru)     Tel: +254 20 3594711 / 2 / 3 / 4

Mob: +254 722 760063: +254 733 771829

VAT REG NO. 0010561U

PIN NO. P000600759T

Manufacturers of Quality Knitwear, Socks, Yarns, Baby Shawls,Kikois,T-Shirts,Polo-Shirts & Caps. Embroiderers & Screen Printers

STUDIO FIT

Invoice Details

P.O BOX 3004700100 NAIROBI

 Customer Info.

Email

Phone

PIN

Atn.

CS283

Invoice Due Date:

Customer A/C No

Payment Terms

As Agreed:::

Our Ref. No

:

Invoice No.

23918

Invoice Date

24-07-2026

::

24-07-2026

A010783288G

ALL AMOUNTS SHOWN IN KESPage 1 of 1HS Code SI NoItem CodeItem DescriptonUomQty.Unit PriceVat%Total AmountACRYLIC KNITTED SHAWL SF JACQUARD WITH KNITTED PLAIN BACK WITH BINDING_BLACK OFF WHITE 18.00PCS 4,000.00101860_AY02_SHAWL 16.00 72,000.00Total Quantty 18 72,000.00Grand TotalFreightTaxNet TotalDiscountSubTotal

▌

▌

▌

▌

▌

▌

▌▌Notes : 1 BAGBased on Sales Orders 17445. Based on Deliveries 23918.▌Delivery Terms : 72,000.00 0.00 0.00 11,520.00

▌

Madhu Shah

Salesman Name- Accounts are net and are strictly payable monthly or on demand. INTEREST will be charged at 2.5% per month on all overdue accounts. 15% Handling charges on all goods returned afer 7 days from date of receipt.- The above goods remain the property of Alpha Knits Ltd. Untl full payment.
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 1);

    expect(model.tsNum, equals('23918'));
    expect(model.buyerPIN, equals('A010783288G'));
    expect(model.totalAmount, equals(83520.0)); // 72,000 + 16% VAT = 83,520
    expect(model.vatAmountA, equals(11520.0));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(1));

    final item = model.itemDetails!.first;
    expect(item.description, equals('ACRYLIC KNITTED SHAWL SF JACQUARD WITH KNITTED PLAIN BACK WITH BINDING_BLACK OFF WHITE'));
    expect(item.itemCode, equals('101860_AY02_SHAWL'));
    expect(item.quantity, equals(18.0));
    expect(item.unitPrice, equals(4640.0)); // 4000 * 1.16 = 4640
    expect(item.itemAmount, equals(83520.0)); // 72000 * 1.16 = 83520
  });

  test('Parse Alpha Knits INV KSH SAMPLE 2 23861.pdf text (Sample 2)', () async {
    const rawText = '''
 P.O. Box 47018 - 00100 GPO - Nairobi, Kenya

Email: info@alphaknits.com OR sales@alphaknits.com

Website: www.alphaknits.com

Factory (Ruiru)     Tel: +254 20 3594711 / 2 / 3 / 4

Mob: +254 722 760063: +254 733 771829

VAT REG NO. 0010561U

PIN NO. P000600759T

Manufacturers of Quality Knitwear, Socks, Yarns, Baby Shawls,Kikois,T-Shirts,Polo-Shirts & Caps. Embroiderers & Screen Printers

METLIN INVESTMENTS LIMITED

Invoice Details

P.O BOX 3000204 NAIROBI

 Customer Info.

Email

vicrous2017@gmail.com

Phone

PIN

Atn.

CM233

Invoice Due Date:

Customer A/C No

Payment Terms

30 Days From Invoice:::

Our Ref. No

:

Invoice No.

23861

Invoice Date

03-07-2026

::

02-08-2026

P052067143Z

ALL AMOUNTS SHOWN IN KESPage 1 of 2HS Code SI NoItem CodeItem DescriptonUomQty.Unit PriceVat%Total AmountBOYS STOCKINGS 3X1 RIB 3 STRIPES GRADUATE :GREY_B W B_S 12.00DOZEN 1,163.841PL0211_ BWB_S 16.00 13,966.02BOYS STOCKINGS 3X1 RIB 3 STRIPES GRADUATE :GREY_B W B_M 12.00PAIR 1,163.842PL0211_ BWB_M 16.00 13,966.02BOYS STOCKINGS 3X1 RIB 3 STRIPES GRADUATE :GREY_B W B_LG 12.00DOZEN 1,163.843PL0211_ BWB_LG 16.00 13,966.02BOYS STOCKINGS 3X1 RIB 3 STRIPES GRADUATE :GREY_B W B_XL 12.00DOZEN 1,163.844PL0211_ BWB_XL 16.00 13,966.02BOYS STOCKINGS 3X1 RIB POLY LYCRA GRADUATE_GREY_MD 12.00DOZEN 1,163.845PL0206_ GREY_MD 16.00 13,966.02BOYS STOCKINGS 3X1 RIB POLY LYCRA GRADUATE_GREY_LG 12.00DOZEN 1,163.846PL0206_ GREY_LG 16.00 13,966.02BOYS STOCKINGS 3X1 RIB POLY LYCRA GRADUATE_GREY_XL 12.00DOZEN 1,163.847PL0206_ GREY_XL 16.00 13,966.02GIRLS STOCKINGS 3X1 RIB GRADUATE POLY LYCRA_WHITE_SM 12.00DOZEN 862.108PL0305_WHT_ SM 16.00 10,345.20GIRLS STOCKINGS 3X1 RIB GRADUATE POLY LYCRA_WHITE_MD 12.00PAIR 862.109PL0305_WHT_ MD 16.00 10,345.20GIRLS STOCKINGS 3X1 RIB GRADUATE POLY LYCRA_WHITE_LG 12.00DOZENS 862.1010PL0305_WHT_ LG 16.00 10,345.20GIRLS STOCKINGS 3X1 RIB GRADUATE  POLY LYCRA_WHITE_XL 12.00DOZENS 862.1011PL0305_WHT_ XL 16.00 10,345.20



ALL AMOUNTS SHOWN IN KESPage 2 of 2HS Code SI NoItem CodeItem DescriptonUomQty.Unit PriceVat%Total AmountGIRLS STOCKINGS 3X1 RIB GRADUATE POLY LYCRA_RED_SM 12.00DOZEN 862.1012PL0305_RED_ SM 16.00 10,345.20GIRLS STOCKINGS 3X1 RIB GRADUATE POLY LYCRA_RED_MD 12.00DOZEN 862.1013PL0305_RED_ MD 16.00 10,345.20GIRLS STOCKINGS 3X1 RIB GRADUATE POLY LYCRA_RED_LG 12.00DOZEN 862.1014PL0305_RED_ LG 16.00 10,345.20GIRLS STOCKINGS 3X1 RIB GRADUATE POLY LYCRA_RED_XL 12.00DOZEN 862.1015PL0305_RED_ XL 16.00 10,345.20Total Quantty 180 180,523.74Grand TotalFreightTaxNet TotalDiscountSubTotal

▌

▌

▌

▌

▌

▌

▌▌Notes : 7 BAGS Based on Sales Orders 17398. Based on Deliveries 23861.▌Delivery Terms : 180,523.74 0.00 0.00 28,883.80

▌

Madhu Shah

Salesman Name- Accounts are net and are strictly payable monthly or on demand. INTEREST will be charged at 2.5% per month on all overdue accounts. 15% Handling charges on all goods returned afer 7 days from date of receipt.- The above goods remain the property of Alpha Knits Ltd. Untl full payment.
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 2);

    expect(model.tsNum, equals('23861'));
    expect(model.buyerPIN, equals('P052067143Z'));
    expect(model.totalAmount, closeTo(209407.54, 0.01)); // 180,523.74 + 28,883.80 = 209,407.54
    expect(model.vatAmountA, equals(28883.80));
    expect(model.currency, equals('KES'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(15));

    final item1 = model.itemDetails!.first;
    expect(item1.description, equals('BOYS STOCKINGS 3X1 RIB 3 STRIPES GRADUATE :GREY_B W B_S'));
    expect(item1.itemCode, equals('PL0211_ BWB_S'));
    expect(item1.quantity, equals(12.0));
    expect(item1.unitPrice, closeTo(1350.05, 0.01)); // (13966.02 * 1.16) / 12
    expect(item1.itemAmount, closeTo(16200.58, 0.01)); // 13966.02 * 1.16

    final item15 = model.itemDetails!.last;
    expect(item15.description, equals('GIRLS STOCKINGS 3X1 RIB GRADUATE POLY LYCRA_RED_XL'));
    expect(item15.itemCode, equals('PL0305_RED_ XL'));
    expect(item15.quantity, equals(12.0));
    expect(item15.unitPrice, closeTo(1000.03, 0.01)); // (10345.20 * 1.16) / 12
    expect(item15.itemAmount, closeTo(12000.43, 0.01)); // 10345.20 * 1.16
  });

  test('Parse Alpha Knits INV USD 23920.pdf text (Sample 3 USD)', () async {
    const rawText = '''
 P.O. Box 47018 - 00100 GPO - Nairobi, Kenya

Email: info@alphaknits.com OR sales@alphaknits.com

Website: www.alphaknits.com

Factory (Ruiru)     Tel: +254 20 3594711 / 2 / 3 / 4

Mob: +254 722 760063: +254 733 771829

VAT REG NO. 0010561U

PIN NO. P000600759T

Manufacturers of Quality Knitwear, Socks, Yarns, Baby Shawls,Kikois,T-Shirts,Polo-Shirts & Caps. Embroiderers & Screen Printers

SIMBA APPAREL (EPZ) LTD

Invoice Details

P.O BOX 9913980107 MOMBASA

 Customer Info.

Email

Phone

PIN

Atn.

CS257

Invoice Due Date:

Customer A/C No

Payment Terms

Immediate:::

Our Ref. No

:

35690; 35650.

Invoice No.

23920

Invoice Date

27-07-2026

::

27-07-2026

P051544407ALL AMOUNTS SHOWN IN USDPage 1 of 1Total AmountVat%Unit PriceQty.UomItem DescriptonItem Code SI NoHS CodeKNITTED POLYESTER CUFFS 1X1 RIB _7.5''X3''_BLACK 216.00PAIRS 0.411PY0824 _ 7.5''X3'' 0.000002.32.00 88.56KNITTED POLYESTER CUFFS 1X1 RIB _7.5''X3''_NAVY BLUE 1200.00PAIRS 0.412PY0824 _7.5''X3'' 0.000002.32.00 492.001X1 RIB KNITTED 100% POLYESTER 5 PLY _N BLUE 99.90KGS 10.35301773 _NAVY 0.000002.32.00 1,033.97Total Quantty 1,516 1,614.53 0.00 0.00 0.00Grand TotalFreightTaxNet TotalDiscountSubTotal

▌

▌

▌

▌

▌

▌

 1,614.53 1,614.53▌Notes : 3 BALES Based on Sales Orders 17361. 17419. Based on Deliveries 23920.▌Delivery Terms :
''';

    final model = await FileGenerator.parsePdfTextToDataModelForTesting(rawText, 3);

    expect(model.tsNum, equals('23920'));
    expect(model.buyerPIN, equals('P051544407A'));
    expect(model.totalAmount, equals(1614.53));
    expect(model.vatAmountA, equals(0.0));
    expect(model.currency, equals('USD'));
    expect(model.itemDetails, isNotNull);
    expect(model.itemDetails!.length, equals(3));

    final item1 = model.itemDetails!.first;
    expect(item1.description, equals("KNITTED POLYESTER CUFFS 1X1 RIB _7.5''X3''_BLACK"));
    expect(item1.itemCode, equals("00023200"));
    expect(item1.quantity, equals(216.0));
    expect(item1.unitPrice, closeTo(0.41, 0.001));
    expect(item1.itemAmount, equals(88.56));

    final item3 = model.itemDetails!.last;
    expect(item3.description, equals('1X1 RIB KNITTED 100% POLYESTER 5 PLY _N BLUE'));
    expect(item3.itemCode, equals('00023200'));
    expect(item3.quantity, equals(99.90));
    expect(item3.unitPrice, closeTo(10.35, 0.01));
    expect(item3.itemAmount, equals(1033.97));
  });
}
