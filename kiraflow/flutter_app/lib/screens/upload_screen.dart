import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import 'result_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();
  Position? _position;
  bool _loading = false;
  String _status = '';

  static const kTeal = Color(0xFF1D9E75);
  static const kTealLight = Color(0xFFE1F5EE);
  static const kDark = Color(0xFF1A1A1A);
  static const kMuted = Color(0xFF6B7280);
  static const kBorder = Color(0xFFE5E7EB);

  @override
  void initState() { super.initState(); _getLocation(); }

  Future<void> _getLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        setState(() => _position = pos);
      }
    } catch (e) { debugPrint('GPS error: $e'); }
  }

  Future<void> _pick() async {
    if (_images.length >= 5) { _snack('Max 5 photos'); return; }
    final imgs = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1200);
    if (imgs.isNotEmpty) setState(() => _images.addAll(imgs.take(5 - _images.length)));
  }

  Future<void> _camera() async {
    if (_images.length >= 5) { _snack('Max 5 photos'); return; }
    final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1200);
    if (img != null) setState(() => _images.add(img));
  }

  Future<void> _analyze() async {
    if (_images.length < 3) { _snack('Add at least 3 photos'); return; }
    if (_position == null) { _snack('Waiting for GPS...'); await _getLocation(); return; }
    setState(() { _loading = true; _status = 'Uploading photos...'; });
    try {
      setState(() => _status = 'Running AI analysis...');
      final result = await ApiService.analyzeStore(images: _images, latitude: _position!.latitude, longitude: _position!.longitude);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(result: result)));
    } catch (e) { _snack('Failed: $e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  static const _labels = ['Shelf 1', 'Shelf 2', 'Counter', 'Exterior 1', 'Exterior 2'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: kTeal, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.store, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Text('KiraFlow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kDark)),
        ]),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16),
            child: _position != null
              ? Row(children: [Icon(Icons.location_on, size: 14, color: kTeal), const SizedBox(width: 4),
                  Text('GPS locked', style: TextStyle(fontSize: 12, color: kTeal, fontWeight: FontWeight.w500))])
              : Row(children: [SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: kMuted)),
                  const SizedBox(width: 6), Text('Getting GPS...', style: TextStyle(fontSize: 12, color: kMuted))])),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kTealLight, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Store assessment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF085041))),
              const SizedBox(height: 4),
              const Text('Upload 3–5 photos to get an AI-powered cash flow estimate.',
                style: TextStyle(fontSize: 13, color: Color(0xFF0F6E56))),
            ])),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Store photos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kDark)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _images.length >= 3 ? kTealLight : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20)),
              child: Text('${_images.length}/5', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: _images.length >= 3 ? kTeal : kMuted))),
          ]),
          const SizedBox(height: 6),
          Text('Include: shelves ×2, counter, exterior ×2', style: TextStyle(fontSize: 12, color: kMuted)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: 5,
            itemBuilder: (_, i) => i < _images.length ? _filledSlot(i) : _emptySlot(i),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _camera,
              icon: const Icon(Icons.camera_alt_outlined, size: 18), label: const Text('Camera'),
              style: OutlinedButton.styleFrom(foregroundColor: kDark, side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: _pick,
              icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(foregroundColor: kDark, side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
          ]),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder)),
            child: Row(children: [
              Icon(Icons.location_on, color: _position != null ? kTeal : kMuted, size: 20),
              const SizedBox(width: 10),
              Expanded(child: _position != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('GPS location captured', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF085041))),
                    Text('${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0F6E56))),
                  ])
                : const Text('Acquiring GPS...', style: TextStyle(fontSize: 13, color: kMuted))),
              if (_position != null) const Icon(Icons.check_circle, color: kTeal, size: 18),
            ])),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: (_loading || _images.length < 3) ? null : _analyze,
              style: ElevatedButton.styleFrom(backgroundColor: kTeal, foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD1D5DB), padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: _loading
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    const SizedBox(width: 10),
                    Text(_status, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ])
                : Text(_images.length < 3 ? 'Add ${3 - _images.length} more photo(s)' : 'Analyse store',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            )),
          const SizedBox(height: 12),
          Center(child: Text('Analysis takes ~10 seconds', style: TextStyle(fontSize: 12, color: kMuted))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _filledSlot(int i) => Stack(children: [
    ClipRRect(borderRadius: BorderRadius.circular(10),
      child: Image.file(File(_images[i].path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
    Positioned(bottom: 0, left: 0, right: 0,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: Colors.black45,
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10), bottomRight: Radius.circular(10))),
        child: Text(_labels[i], textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)))),
    Positioned(top: 4, right: 4,
      child: GestureDetector(onTap: () => setState(() => _images.removeAt(i)),
        child: Container(width: 22, height: 22,
          decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 13, color: Colors.white)))),
  ]);

  Widget _emptySlot(int i) {
    final isNext = i == _images.length;
    return GestureDetector(onTap: isNext ? _camera : null,
      child: Container(
        decoration: BoxDecoration(
          color: isNext ? kTealLight : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isNext ? kTeal : kBorder, width: isNext ? 1.5 : 1)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isNext ? Icons.add_a_photo_outlined : Icons.photo_outlined, size: 22,
            color: isNext ? kTeal : const Color(0xFFD1D5DB)),
          const SizedBox(height: 4),
          Text(_labels[i], textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: isNext ? kTeal : const Color(0xFFD1D5DB), fontWeight: FontWeight.w500)),
        ])));
  }
}
