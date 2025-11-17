import 'dart:typed_data';
import 'package:flutter_thermal_printer/network/network_print_result.dart';
import 'package:image/image.dart' as img;

import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:screenshot/screenshot.dart';
import '../model/receipt_model.dart';
import '../utils/localizations_portal.dart';
import '../widgets/receipt_widget.dart';
import '../widgets/service_receipt_widget.dart';

class ReceiptPrinter {

  /// 🖨️ طباعة الفاتورة الرئيسية والخدمات
  static Future<void> printReceipt(
      Map<String, dynamic> data,
      BuildContext context,
      ) async {
    try {
      print(" بدء عملية الطباعة الكاملة");
      final receiptModel = ReceiptModel(data: data);

      // 1. أولاً: طباعة فاتورة الكاشير الرئيسية
      await _printCashierReceipt(receiptModel, context);

      // 2. ثانياً: طباعة فواتير الخدمات لكل printerIp
      await _printServiceReceipts(receiptModel, context);


      print(" اكتملت عملية الطباعة بنجاح");

    } catch (e) {
      print(" خطأ عام في الطباعة: $e");
      rethrow;
    }
  }


  static Future<void> _printServiceReceipts(
      ReceiptModel receiptModel,
      BuildContext context,
      ) async {
    try {
      final orderDetails = receiptModel.orderDetails;

      if (orderDetails.isEmpty) {
        print("ℹ️ لا توجد خدمات للطباعة");
        return;
      }

      print("🛠️ بدء طباعة ${orderDetails.length} فاتورة خدمة");

      for (final entry in orderDetails.entries) {
        final printerIp = entry.key;
        final services = entry.value;

        print("🖨️ طابعة الخدمة: $printerIp عدد الخدمات: ${services.length}");

        for (final service in services) {
          print("🛠️ بدء طباعة خدمة: ${service.name}");

          final serviceWidget = ServiceReceiptWidget(
            receiptModel: receiptModel,
            printerIp: printerIp,
            serviceItem: service,
          );

          await _printServiceDirectViaNetwork(printerIp, serviceWidget, context);

          print("✅ تمت طباعة الخدمة: ${service.name} على $printerIp");
        }
      }

      print("✅ اكتملت طباعة فواتير الخدمات");

    } catch (e) {
      print("❌ خطأ في طباعة فواتير الخدمات: $e");
    }
  }




  /// 💰 طباعة فاتورة الكاشير الرئيسية
  static Future<void> _printCashierReceipt(ReceiptModel receiptModel, BuildContext context) async {
    try {
      final mainPrinterIp = receiptModel.printerIp;

      if (mainPrinterIp == null || mainPrinterIp.isEmpty) {
        print("⚠️ لا يوجد طابعة رئيسية للفاتورة");
        return;
      }

      print("💰 بدء طباعة فاتورة الكاشير على: $mainPrinterIp");


      // استخدام الطباعة المباشرة بدون connect
      await _printDirectViaNetwork(mainPrinterIp, receiptModel.data, context);

      print("✅ تمت طباعة فاتورة الكاشير بنجاح على: $mainPrinterIp");

    } catch (e) {
      print("❌ خطأ في طباعة فاتورة الكاشير: $e");
      print("🔍 تفاصيل الخطأ: ${e.toString()}");
    }
  }


  static Future<void> _printServiceDirectViaNetwork(
      String printerIp,
      Widget serviceWidget,
      BuildContext context,
      ) async {
    try {
      final port = 9100;

      print("🌐 محاولة الطباعة المباشرة للخدمة على: $printerIp:$port");

      // إنشاء bytes بنفس طريقة الفاتورة الرئيسية
      final bytes = await _generateServiceReceiptBytes(serviceWidget, context);
      print("📦 حجم بيانات الخدمة: ${bytes.length} bytes");

      final networkPrinter = FlutterThermalPrinterNetwork(printerIp, port: port);

      print("🔌 محاولة الاتصال بطابعة الخدمة...");
      NetworkPrintResult con = await networkPrinter.connect();

      if (con.value == 1) {
        print("✅ تم الاتصال بطابعة الخدمة");
      } else {
        print("❌ فشل الاتصال بطابعة الخدمة");
        return;
      }

      print("🖨️ بدء إرسال بيانات الخدمة...");
      await networkPrinter.printTicket(bytes);
      print("✅ تم إرسال بيانات الخدمة بنجاح");
      await networkPrinter.printTicket([0x1D, 0x56, 0x00]);

      print("🔌 قطع الاتصال...");
      await networkPrinter.disconnect();
      print("✅ تم قطع الاتصال");

    } catch (e) {
      print("❌ خطأ في الطباعة المباشرة للخدمة على $printerIp: $e");
    }
  }



  /// 🌐 الطباعة المباشرة عبر الشبكة للفاتورة الرئيسية
  static Future<void> _printDirectViaNetwork(
      String printerIp,
      Map<String, dynamic> data,
      BuildContext context,
      ) async {

    try {
      final port = 9100; // المنفذ الافتراضي للطابعات الحرارية

      print("🌐 محاولة الطباعة المباشرة على: $printerIp:$port");

      // إنشاء bytes الفاتورة
      List<int> bytes = await _generateReceiptBytes(data, context);
      print("📦 حجم البيانات المُنشأة: ${bytes.length} bytes");

      // استخدام FlutterThermalPrinterNetwork للطباعة المباشرة
      final networkPrinter = FlutterThermalPrinterNetwork(printerIp, port: port);

      print("🔌 محاولة الاتصال بالطابعة...");
      NetworkPrintResult  networkPrintResult = await networkPrinter.connect();
      if(networkPrintResult.value == 1){
        print("✅ تم الاتصال بالطابعة");
      }else{
        print(" فشل الاتصال بالطابعة");

      }

      print("🖨️ بدء إرسال البيانات للطباعة...");
      await networkPrinter.printTicket(bytes);
      print("✅ تم إرسال البيانات بنجاح");
      await networkPrinter.printTicket([0x1D, 0x56, 0x00]);

      print("🔌 قطع الاتصال...");
      await networkPrinter.disconnect();
      print("✅ تم قطع الاتصال");

    } catch (e) {
      print("❌ خطأ في الطباعة المباشرة على $printerIp: $e");

      // محاولة بديلة باستخدام الطباعة عبر الصورة
      print("🔄 جارٍ تجربة الطريقة البديلة...");
    }
  }

  static Future<List<int>> _generateServiceReceiptBytes(
      Widget serviceWidget,
      BuildContext context,
      ) async {
    try {
      print("📸 جاري إنشاء صورة فاتورة الخدمة...");

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);

      // نفس أسلوب الفاتورة الرئيسية: Screenshot → BMP → decode
      List<int> finalBytes = [];
      if (context.mounted) {
        finalBytes = await screenShotWidget(
          context,
          generator: generator,
          widget: serviceWidget,
        );

        print("📸 تم إنشاء صورة الفاتورة (Service) بحجم: ${finalBytes.length} bytes");
        print("📦 الحجم النهائي لبيانات الخدمة: ${finalBytes.length} bytes");
      }

      return finalBytes;
    } catch (e) {
      print("❌ خطأ في _generateServiceReceiptBytes: $e");
      rethrow;
    }
  }

  static Future<List<int>> _generateReceiptBytes(
      Map<String, dynamic> data,
      BuildContext context,
      ) async {
    try {
      print("📸 جاري إنشاء صورة الفاتورة...");
      final receiptModel = ReceiptModel(data: data);
      final widget = ReceiptWidget(receiptModel: receiptModel);

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      final Uint8List screenshotBytes = await FlutterThermalPrinter.instance.screenShotWidget(
        context,
        generator: generator,
        widget: widget,
      );

      // final controller = ScreenshotController();
      List<int> finalBytes = [];
      if (context.mounted) {
        finalBytes = await screenShotWidget(
          context,
          generator: generator,
          widget: widget,
        );

        print("📸 تم إنشاء الصورة بحجم: ${finalBytes.length} bytes");


        // finalBytes = screenshotBytes;
        // finalBytes.addAll([0x0A, 0x0A, 0x0A]); // إضافة أسطر فارغة
        // finalBytes.addAll([0x1B, 0x69]); // أمر قطع الورق
      }

      print("📦 الحجم النهائي للبيانات: ${finalBytes.length} bytes");

      return finalBytes;
    } catch (e) {
      print("❌ خطأ في _generateReceiptBytes: $e");
      rethrow;
    }
  }

  static Future<Uint8List> screenShotWidget(
      BuildContext context, {
        required Widget widget,
        Duration delay = const Duration(milliseconds: 100),
        int? customWidth,
        PaperSize paperSize = PaperSize.mm80,
        Generator? generator,
      }) async {
    final controller = ScreenshotController();
    final image = await controller.captureFromWidget(
      buildScreenshot(context, widget),
      context: context,
      pixelRatio: 3.0,
    );

    Generator? generator0;
    if (generator == null) {
      final profile = await CapabilityProfile.load();
      generator0 = Generator(paperSize, profile);
    } else {
      final profile = await CapabilityProfile.load();
      generator0 = Generator(paperSize, profile);
    }

    img.Image? decodedImage = img.decodeImage(image);
    Uint8List safeBitmapBytes = img.encodeBmp(decodedImage!);
    img.Image? imagebytes = img.decodeBmp(safeBitmapBytes);

    if (customWidth != null) {
      final width = _makeDivisibleBy8(customWidth);
      imagebytes = img.copyResize(imagebytes!, width: width);
    }

    imagebytes = _buildImageRasterAvaliable(imagebytes!);
    imagebytes = img.grayscale(imagebytes);

    final totalheight = imagebytes.height;
    final totalwidth = imagebytes.width;

    // ✅ الحل: استخدام ارتفاع ديناميكي بناءً على المحتوى
    int imageChunkHeight = _calculateOptimalChunkHeight(totalheight);

    List<int> bytes = [];

    // ✅ معالجة كل جزء من الصورة
    for (var i = 0; i < (totalheight / imageChunkHeight).ceil(); i++) {
      final startY = i * imageChunkHeight;
      final chunkHeight = (startY + imageChunkHeight > totalheight)
          ? totalheight - startY
          : imageChunkHeight;

      final croppedImage = img.copyCrop(
        imagebytes,
        x: 0,
        y: startY,
        width: totalwidth,
        height: chunkHeight,
      );

      final raster = generator0.imageRaster(
        croppedImage,
        imageFn: PosImageFn.bitImageRaster,
      );
      bytes += raster;
    }

    // ✅ إضافة أسفل فارغ وأمر قطع الورق
    bytes.addAll(List.filled(6, 0x0A)); // feed lines
    bytes.addAll([0x1D, 0x56, 0x00]);   // cut

    return Uint8List.fromList(bytes);
  }

  static int _makeDivisibleBy8(int number) {
    if (number % 8 == 0) {
      return number;
    }
    return number + (8 - (number % 8));
  }

  static int _calculateOptimalChunkHeight(int totalHeight) {
    print("📏 الارتفاع الكلي للصورة: $totalHeight بكسل");

    // ✅ تحسين الخوارزمية بناءً على الارتفاع الفعلي
    const int maxChunkHeight = 256; // أقصى ارتفاع للطابعة

    if (totalHeight <= maxChunkHeight) {
      return totalHeight; // لا حاجة للتقسيم
    }

    // ✅ حساب عدد الأجزاء المثالي
    int optimalParts = (totalHeight / maxChunkHeight).ceil();
    int chunkHeight = (totalHeight / optimalParts).ceil();

    // ✅ التأكد من أن الارتفاع قابل للقسمة على 8
    chunkHeight = _makeDivisibleBy8(chunkHeight);

    print("📦 سيتم التقسيم إلى $optimalParts أجزاء، ارتفاع كل جزء: $chunkHeight");

    return chunkHeight;
  }

  static img.Image _buildImageRasterAvaliable(img.Image image) {
    final avaliable = image.width % 8 == 0;
    if (avaliable) {
      return image;
    }
    final newWidth = _makeDivisibleBy8(image.width);
    return img.copyResize(image, width: newWidth);
  }



  static Widget buildScreenshot(BuildContext context, Widget receiptWidget) {
    // نمرر context الأصلي عشان نقدر نجيب locale
    return LocalizationsPortal(
      originalContext: context,
      child: receiptWidget,
    );
  }



}