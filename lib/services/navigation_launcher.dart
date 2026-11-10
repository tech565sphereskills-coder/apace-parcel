import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

class NavigationLauncher {
  static String formatDestinationQuery({
    required String address,
    String? landmark,
    double? lat,
    double? lng,
  }) {
    if (lat != null && lng != null) {
      return '$lat,$lng';
    }
    final cleanLandmark = (landmark ?? '').trim();
    if (cleanLandmark.isNotEmpty) {
      return '$address, $cleanLandmark, Nigeria';
    }
    return '$address, Nigeria';
  }

  static Future<void> launchGoogleMaps({
    required BuildContext context,
    required String address,
    String? landmark,
    double? lat,
    double? lng,
    String serviceType = 'BIKE',
  }) async {
    final destQuery = formatDestinationQuery(
      address: address,
      landmark: landmark,
      lat: lat,
      lng: lng,
    );
    final encodedDest = Uri.encodeComponent(destQuery);
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    if (isAndroid) {
      final navUri = Uri.parse('google.navigation:q=$encodedDest&mode=d');
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri, mode: LaunchMode.externalApplication);
        return;
      }
      final geoUri = Uri.parse('geo:${lat ?? 6.5244},${lng ?? 3.3792}?q=$encodedDest');
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    } else if (isIos) {
      final comGoogleUri = Uri.parse('comgooglemaps://?daddr=$encodedDest&directionsmode=driving');
      if (await canLaunchUrl(comGoogleUri)) {
        await launchUrl(comGoogleUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$encodedDest&travelmode=driving',
    );
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Route target copied: $destQuery'),
          backgroundColor: AppColors.primaryOrange,
        ),
      );
      await Clipboard.setData(ClipboardData(text: destQuery));
    }
  }

  static Future<void> launchWaze({
    required BuildContext context,
    required String address,
    double? lat,
    double? lng,
  }) async {
    final query = lat != null && lng != null
        ? 'll=$lat,$lng&navigate=yes'
        : 'q=${Uri.encodeComponent('$address, Nigeria')}&navigate=yes';
    final uri = Uri.parse('https://waze.com/ul?$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      await launchGoogleMaps(context: context, address: address, lat: lat, lng: lng);
    }
  }

  static Future<void> launchAppleOrGeoMaps({
    required BuildContext context,
    required String address,
    double? lat,
    double? lng,
  }) async {
    final target = Uri.encodeComponent(
      formatDestinationQuery(address: address, lat: lat, lng: lng),
    );
    final uri = Uri.parse('https://maps.apple.com/?daddr=$target&dirflg=d');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      await launchGoogleMaps(context: context, address: address, lat: lat, lng: lng);
    }
  }

  static Future<void> launchMultiStopCorridor({
    required BuildContext context,
    required String pickupAddress,
    double? pickupLat,
    double? pickupLng,
    required List<Map<String, dynamic>> stops,
  }) async {
    if (stops.isEmpty) return;

    final origin = Uri.encodeComponent(
      formatDestinationQuery(address: pickupAddress, lat: pickupLat, lng: pickupLng),
    );

    final formattedStops = stops.map((s) {
      return Uri.encodeComponent(
        formatDestinationQuery(
          address: s['address']?.toString() ?? '',
          landmark: s['landmark']?.toString(),
          lat: (s['lat'] as num?)?.toDouble(),
          lng: (s['lng'] as num?)?.toDouble(),
        ),
      );
    }).toList();

    final finalDest = formattedStops.last;
    final waypoints = formattedStops.length > 1
        ? formattedStops.sublist(0, formattedStops.length - 1).join('|')
        : '';

    final url = waypoints.isNotEmpty
        ? 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$finalDest&waypoints=$waypoints&travelmode=driving'
        : 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$finalDest&travelmode=driving';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open multi-stop corridor in browser/maps.')),
      );
    }
  }

  static Future<void> launchWhatsAppRecipientPing({
    required BuildContext context,
    required String phone,
    required String recipientName,
    required String destination,
    required String orderId,
  }) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final intl = digits.startsWith('0') && digits.length >= 11
        ? '234${digits.substring(1)}'
        : (digits.startsWith('234') ? digits : '234$digits');
    final msg = Uri.encodeComponent(
      'Hello $recipientName, I am your Apace Dispatch rider for Order #$orderId heading to $destination via Google Maps. Kindly prepare your handover OTP or share a WhatsApp location pin if inside an estate.',
    );
    final waUri = Uri.parse('https://wa.me/$intl?text=$msg');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recipient WhatsApp number: $phone')),
      );
    }
  }

  static void showMapAppChooser(
    BuildContext context, {
    required String label,
    required String address,
    String? landmark,
    double? lat,
    double? lng,
    String serviceType = 'BIKE',
  }) {
    final cleanAddress = landmark != null && landmark.trim().isNotEmpty
        ? '$address ($landmark)'
        : address;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF334155))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ROUTE TO $label',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF38BDF8),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cleanAddress,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            if (lat != null && lng != null)
              Text(
                'GPS Lock: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            const SizedBox(height: 14),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF15803D),
                child: Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
              ),
              title: const Text('Google Maps Turn-by-Turn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: const Text('Live Lagos traffic & shortest dispatch lane', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              trailing: const Icon(Icons.open_in_new_rounded, color: Color(0xFF38BDF8), size: 18),
              onTap: () {
                Navigator.pop(ctx);
                launchGoogleMaps(
                  context: context,
                  address: address,
                  landmark: landmark,
                  lat: lat,
                  lng: lng,
                  serviceType: serviceType,
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF0284C7),
                child: Icon(Icons.directions_car_rounded, color: Colors.white, size: 20),
              ),
              title: const Text('Waze Community Traffic', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: const Text('Real-time LASTMA / checkpoint & flood alerts', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              trailing: const Icon(Icons.open_in_new_rounded, color: Color(0xFF38BDF8), size: 18),
              onTap: () {
                Navigator.pop(ctx);
                launchWaze(context: context, address: address, lat: lat, lng: lng);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF334155),
                child: Icon(Icons.map_rounded, color: Colors.white, size: 20),
              ),
              title: const Text('Apple Maps / Web Directions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: const Text('Fallback browser or iOS system navigation', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                launchAppleOrGeoMaps(context: context, address: address, lat: lat, lng: lng);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1E293B),
                child: Icon(Icons.copy_rounded, color: AppColors.primaryOrange, size: 18),
              ),
              title: const Text('Copy Address & Landmark', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(ClipboardData(text: cleanAddress));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address & Landmark copied to clipboard!'),
                      backgroundColor: AppColors.emeraldGreen,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

