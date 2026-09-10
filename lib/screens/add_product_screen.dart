import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import '../services/bg_removal_service.dart';
import '../services/pricing_service.dart';
import '../widgets/product_composite.dart';
import '../widgets/backdrop_picker.dart';


// ============================================================
// ADD PRODUCT SCREEN
// ============================================================

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}


class _AddProductScreenState extends State<AddProductScreen> {
  int currentStep = 0;

  Uint8List? productImage;

  String voiceText = '';
  String productTitle = '';
  String productDescription = '';
  String productMaterials = '';
  String productCategory = '';
  List<String> productTags = [];

  // New: fields extracted by Gemini from voice, used for pricing.
  String productState = 'Andhra Pradesh';
  String productRegion = 'South';
  String productSize = 'Medium';
  int productComplexity = 3;
  String productQuality = 'Medium';

  double labourHours = 5;
  double labourRate = 50;
  double labourCost = 250;
  double materialCost = 250;
  double currentMarketPrice = 650;

  double finalPrice = 650;

  final steps = ['Photo', 'Details', 'Price', 'Done'];

  Future<void> _saveProductToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('No user is logged in.');
        return;
      }

      if (productImage == null) {
        debugPrint('No product image found.');
        return;
      }

      // Chrome/web uses localhost. Android emulator will use 10.0.2.2.
      final backendUrl = kIsWeb
          ? 'http://localhost:8000'
          : 'http://10.0.2.2:8000';

      // Upload the product image to FastAPI.
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/upload-image'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          productImage!,
          filename: 'product.png',
        ),
      );

      final streamedResponse = await request.send();

      final response = await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode != 200) {
        throw Exception(
      'Image upload failed: ${response.statusCode}\n${response.body}',
    );
      }

      final uploadData = jsonDecode(response.body);

      if (uploadData['success'] != true) {
        throw Exception(
          uploadData['error']?.toString() ?? 'Image upload failed.',
        );
      }

      final imageUrl = uploadData['imageUrl']?.toString();

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('FastAPI did not return an image URL.');
      }

      // Create a Firestore product document.
      final productRef =
          FirebaseFirestore.instance.collection('products').doc();

      await productRef.set({
        'id': productRef.id,
        'ownerId': user.uid,
        'ownerEmail': user.email ?? '',
        'title': productTitle,
        'description': productDescription,
        'materials': productMaterials,
        'category': productCategory,
        'tags': productTags,
        'price': finalPrice,
        'status': 'Listed',
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),

        // Pricing breakdown, kept for reference / re-editing later.
        'state': productState,
        'region': productRegion,
        'productSize': productSize,
        'complexity': productComplexity,
        'quality': productQuality,
        'labourHours': labourHours,
        'labourRate': labourRate,
        'labourCost': labourCost,
        'materialCost': materialCost,
        'currentMarketPrice': currentMarketPrice,
      });

      debugPrint('Product saved successfully.');
      debugPrint('Image URL: $imageUrl');
    } catch (e) {
      debugPrint('Failed to save product: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF6EE),

      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF6EE),
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'Add Product',
          style: TextStyle(color: Colors.black87),
        ),
      ),

      body: Column(
        children: [
          _StepIndicator(
            steps: steps,
            currentStep: currentStep,
          ),

          const SizedBox(height: 30),

          Expanded(
            child: _buildStepContent(),
          ),
        ],
      ),
    );
  }


  Widget _buildStepContent() {
    switch (currentStep) {
      case 0:
        return _PhotoStep(
          onPhotoReady: (img) {
            setState(() {
              productImage = img;
              currentStep = 1;
            });
          },
        );

      case 1:
        return _DetailsStep(
          onGenerated: (result) {
            setState(() {
              voiceText = result.voiceText;
              productTitle = result.title;
              productDescription = result.description;
              productMaterials = result.materials;
              productCategory = result.category;
              productTags = result.tags;

              productState = result.state;
              productRegion = result.region;
              productSize = result.productSize;
              productComplexity = result.complexity;
              productQuality = result.quality;

              labourHours = result.labourHours;
              labourRate = result.labourRate;
              labourCost = result.labourCost;
              materialCost = result.materialCost;
              currentMarketPrice = result.currentMarketPrice;

              finalPrice = result.predictedPrice;

              currentStep = 2;
            });
          },
        );

      case 2:
        return _PriceStep(
          initialPrice: finalPrice,
          state: productState,
          region: productRegion,
          category: productCategory.isEmpty ? 'Home Decor' : productCategory,
          material: productMaterials.isEmpty ? 'Mixed' : productMaterials,
          materialCost: materialCost,
          labourCost: labourCost,
          labourHours: labourHours,
          productSize: productSize,
          complexity: productComplexity,
          currentMarketPrice: currentMarketPrice,
          demandScore: productQuality.toLowerCase() == 'high'
              ? 0.85
              : productQuality.toLowerCase() == 'low'
                  ? 0.4
                  : 0.6,

          onNext: (price) async {
            setState(() {
              finalPrice = price;
            });

            await _saveProductToFirestore();

            if (!mounted) return;

            setState(() {
              currentStep = 3;
            });
          },
        );

      case 3:
        return _DoneStep(
          title: productTitle.isEmpty
              ? 'KALA AI Product'
              : productTitle,

          price: '₹${finalPrice.toStringAsFixed(0)}',

          image: productImage,

          tags: productTags,

          onViewProduct: () {
            context.go('/home');
          },

          onAddAnother: () {
            setState(() {
              currentStep = 0;
              productImage = null;
              voiceText = '';
              productTitle = '';
              productDescription = '';
              productMaterials = '';
              productCategory = '';
              productTags = [];

              productState = 'Andhra Pradesh';
              productRegion = 'South';
              productSize = 'Medium';
              productComplexity = 3;
              productQuality = 'Medium';

              labourHours = 5;
              labourRate = 50;
              labourCost = 250;
              materialCost = 250;
              currentMarketPrice = 650;

              finalPrice = 650;
            });
          },
        );

      default:
        return const SizedBox();
    }
  }
}


// ============================================================
// STEP INDICATOR
// ============================================================

class _StepIndicator extends StatelessWidget {
  final List<String> steps;
  final int currentStep;

  const _StepIndicator({
    required this.steps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,

        children: List.generate(
          steps.length,

          (index) {
            final isActive = index <= currentStep;

            return Row(
              children: [
                CircleAvatar(
                  radius: 14,

                  backgroundColor: isActive
                      ? const Color(0xFF1E7A4C)
                      : Colors.black12,

                  child: Text(
                    '${index + 1}',

                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : Colors.black45,

                      fontSize: 12,
                    ),
                  ),
                ),

                if (index != steps.length - 1)
                  Container(
                    width: 30,
                    height: 2,

                    color: index < currentStep
                        ? const Color(0xFF1E7A4C)
                        : Colors.black12,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}


// ============================================================
// STEP 1: PHOTO
// ============================================================

class _PhotoStep extends StatefulWidget {
  final void Function(Uint8List processedImage) onPhotoReady;

  const _PhotoStep({
    required this.onPhotoReady,
  });

  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}


class _PhotoStepState extends State<_PhotoStep> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _originalBytes;
  Uint8List? _processedBytes;

  bool _isProcessing = false;

  String? _error;

  BackdropStyle _selectedBackdrop =
      BackdropStyle.studioWhite;


  Future<void> _pickAndProcess(
    ImageSource source,
  ) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _originalBytes = bytes;
      _isProcessing = true;
      _error = null;
    });

    final result =
        await BgRemovalService.removeBackground(bytes);

    setState(() {
      _isProcessing = false;
      _processedBytes = result;

      if (result == null) {
        _error =
            'Background removal failed. Check your API key/quota.';
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          if (_originalBytes == null) ...[
            InkWell(
              onTap: () =>
                  _pickAndProcess(ImageSource.camera),

              borderRadius: BorderRadius.circular(16),

              child: Container(
                width: double.infinity,

                padding: const EdgeInsets.symmetric(
                  vertical: 50,
                ),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(16),

                  border:
                      Border.all(color: Colors.black12),
                ),

                child: const Column(
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 40,
                      color: Colors.black54,
                    ),

                    SizedBox(height: 12),

                    Text(
                      'Take a Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(
                      'of your product',
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'or',
              style: TextStyle(
                color: Colors.black45,
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton.icon(
                onPressed: () =>
                    _pickAndProcess(ImageSource.gallery),

                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF1E7A4C),

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 16,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),

                icon: const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white,
                ),

                label: const Text(
                  'Choose from gallery',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ] else ...[
            if (_isProcessing)
              Container(
                height: 260,
                width: double.infinity,

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(16),

                  border:
                      Border.all(color: Colors.black12),
                ),

                child: const Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF1E7A4C),
                      ),

                      SizedBox(height: 12),

                      Text(
                        'Removing background...',
                        style: TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_processedBytes != null) ...[
              ProductComposite(
                cutoutPngBytes:
                    _processedBytes!,

                backdropStyle:
                    _selectedBackdrop,
              ),

              const SizedBox(height: 12),

              BackdropPicker(
                selected:
                    _selectedBackdrop,

                onSelect: (style) {
                  setState(() {
                    _selectedBackdrop =
                        style;
                  });
                },
              ),
            ]
            else
              Container(
                height: 260,
                width: double.infinity,

                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(16),

                  border:
                      Border.all(color: Colors.black12),
                ),

                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(16),

                  child: Image.memory(
                    _originalBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            if (_error != null)
              Text(
                _error!,
                style:
                    const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 16),

            if (!_isProcessing) ...[
              SizedBox(
                width: double.infinity,

                child: ElevatedButton(
                  onPressed: () {
                    widget.onPhotoReady(
                      _processedBytes ??
                          _originalBytes!,
                    );
                  },

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF1E7A4C),

                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),

                  child: const Text(
                    'Use this photo',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () {
                  setState(() {
                    _originalBytes = null;
                    _processedBytes = null;
                    _error = null;
                  });
                },

                child: const Text(
                  'Retake',
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}


// ============================================================
// RESULT OBJECT PASSED FROM DETAILS STEP TO THE SCREEN
// ============================================================
// Bundled into one object instead of many named parameters,
// since /generate-listing now returns many more fields than
// the old /generate-description did.

class DetailsStepResult {
  final String voiceText;
  final String title;
  final String description;
  final String materials;
  final String category;
  final List<String> tags;

  final String state;
  final String region;
  final String productSize;
  final int complexity;
  final String quality;

  final double labourHours;
  final double labourRate;
  final double labourCost;
  final double materialCost;
  final double currentMarketPrice;

  final double predictedPrice;

  DetailsStepResult({
    required this.voiceText,
    required this.title,
    required this.description,
    required this.materials,
    required this.category,
    required this.tags,
    required this.state,
    required this.region,
    required this.productSize,
    required this.complexity,
    required this.quality,
    required this.labourHours,
    required this.labourRate,
    required this.labourCost,
    required this.materialCost,
    required this.currentMarketPrice,
    required this.predictedPrice,
  });
}


// ============================================================
// STEP 2: VOICE → WHISPER → GEMINI (+ AUTO PRICING)
// ============================================================

class _DetailsStep extends StatefulWidget {
  final void Function(DetailsStepResult result) onGenerated;

  const _DetailsStep({
    required this.onGenerated,
  });

  @override
  State<_DetailsStep> createState() =>
      _DetailsStepState();
}


class _DetailsStepState extends State<_DetailsStep> {
  final AudioRecorder _recorder =
      AudioRecorder();

  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isGenerating = false;

  String _transcribedText = '';

  DetailsStepResult? _result;

  String? _error;


  // Web build (Chrome) → localhost. Android emulator → 10.0.2.2.
  static String get _backendUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    return 'http://10.0.2.2:8000';
  }


  // ----------------------------------------------------------
  // START RECORDING
  // ----------------------------------------------------------

  Future<void> _startRecording() async {
    try {
      final hasPermission =
          await _recorder.hasPermission();

      if (!hasPermission) {
        setState(() {
          _error =
              'Microphone permission was denied.';
        });

        return;
      }

      // On Android, build a real writable temp-file path.
      // On web, path_provider has no implementation, so just
      // pass a placeholder filename — the record package
      // handles storage internally in the browser.
      String filePath = 'kala_voice.m4a';

      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        filePath =
            '${dir.path}/kala_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _error = null;

        _transcribedText = '';
        _result = null;
      });
    } catch (e) {
      setState(() {
        _error =
            'Recording error: $e';
      });
    }
  }


  // ----------------------------------------------------------
  // STOP RECORDING
  // ----------------------------------------------------------

  Future<void> _stopRecording() async {
    try {
      final path =
          await _recorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (path == null || path.isEmpty) {
        setState(() {
          _error =
              'No audio was recorded.';
        });

        return;
      }

      await _sendAudioToWhisper(path);
    } catch (e) {
      setState(() {
        _isRecording = false;

        _error =
            'Could not stop recording: $e';
      });
    }
  }


  // ----------------------------------------------------------
  // WHISPER
  // ----------------------------------------------------------

  Future<void> _sendAudioToWhisper(
    String path,
  ) async {
    setState(() {
      _isTranscribing = true;
      _error = null;
    });

    try {
      final request =
          http.MultipartRequest(
        'POST',
        Uri.parse(
          '$_backendUrl/transcribe',
        ),
      );

      if (kIsWeb) {
        // On web, `path` is actually a blob URL — fetch its
        // bytes first, since dart:io File paths don't exist
        // in the browser.
        final blobResponse =
            await http.get(Uri.parse(path));

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            blobResponse.bodyBytes,
            filename: 'kala_voice.m4a',
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            path,
            filename: 'kala_voice.m4a',
          ),
        );
      }

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Whisper failed: '
          '${response.statusCode}\n'
          '${response.body}',
        );
      }

      final data =
          jsonDecode(response.body);

      final text =
          data['text']?.toString().trim() ?? '';

      if (text.isEmpty) {
        throw Exception(
          'Whisper returned empty text.',
        );
      }

      setState(() {
        _transcribedText = text;
      });

      // IMPORTANT:
      // Immediately send Whisper text to Gemini + pricing.
      await _generateListing(text);
    } catch (e) {
      setState(() {
        _error =
            'Could not process your voice.\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }


  // ----------------------------------------------------------
  // GEMINI + AUTO PRICING (single call to /generate-listing)
  // ----------------------------------------------------------

  Future<void> _generateListing(
    String text,
  ) async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final response =
          await http.post(
        Uri.parse(
          '$_backendUrl/generate-listing',
        ),

        headers: {
          'Content-Type':
              'application/json',
          'Accept':
              'application/json',
        },

        body: jsonEncode({
          'text': text,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Listing generation failed: '
          '${response.statusCode}\n'
          '${response.body}',
        );
      }

            final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (data['error'] != null) {
        // The backend now distinguishes "you forgot to say
        // something required" from a real failure. Show the
        // first one as a friendly prompt instead of a raw
        // exception message.
        if (data['error'] == 'missing_required_fields' ||
            data['error'] == 'unsupported_state') {
          setState(() {
            _error = data['message']?.toString() ??
                'Please mention your state, hours worked, and material cost, then record again.';
          });
          return;
        }

        throw Exception(data['error'].toString());
      }

      double asDouble(dynamic v, double fallback) {
        if (v == null) return fallback;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString()) ?? fallback;
      }

      int asInt(dynamic v, int fallback) {
        if (v == null) return fallback;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString()) ?? fallback;
      }

      final result = DetailsStepResult(
        voiceText: text,
        title: data['title']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        materials: data['materials']?.toString() ?? '',
        category: data['category']?.toString() ?? '',
        tags: (data['tags'] as List?)
                ?.map((t) => t.toString())
                .toList() ??
            [],

        state: data['state']?.toString() ?? 'Andhra Pradesh',
        region: data['region']?.toString() ?? 'South',
        productSize: data['product_size']?.toString() ?? 'Medium',
        complexity: asInt(data['complexity'], 3),
        quality: data['quality']?.toString() ?? 'Medium',

        labourHours: asDouble(data['labour_hours'], 5),
        labourRate: asDouble(data['labour_rate'], 50),
        labourCost: asDouble(data['labour_cost'], 250),
        materialCost: asDouble(data['material_cost'], 250),
        currentMarketPrice: asDouble(data['current_market_price'], 650),

        predictedPrice: asDouble(data['predicted_price'], 650),
      );

      setState(() {
        _result = result;
      });
    } catch (e) {
      setState(() {
        _error =
            'Could not generate AI product listing.\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }


  // ----------------------------------------------------------
  // CONTINUE
  // ----------------------------------------------------------

  void _continue() {
    if (_result == null || _result!.title.isEmpty) {
      setState(() {
        _error =
            'Please record your product details first.';
      });

      return;
    }

    widget.onGenerated(_result!);
  }


  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }


  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isBusy =
        _isRecording ||
        _isTranscribing ||
        _isGenerating;

    final result = _result;


    return SingleChildScrollView(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
      ),

      child: Column(
        children: [
          const SizedBox(height: 20),

          // Microphone
          GestureDetector(
            onTap: isBusy
                ? (_isRecording
                    ? _stopRecording
                    : null)
                : _startRecording,

            child: Container(
              width: 140,
              height: 140,

              decoration:
                  BoxDecoration(
                color: _isRecording
                    ? Colors.red.shade100
                    : const Color(0xFFE9F5EC),

                shape: BoxShape.circle,
              ),

              child: Icon(
                _isRecording
                    ? Icons.stop
                    : Icons.mic,

                size: 56,

                color: _isRecording
                    ? Colors.red
                    : const Color(0xFF1E7A4C),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            _isRecording
                ? 'Listening...'
                : _isGenerating
                    ? 'Creating your product listing...'
                    : 'Tell us about your product',

            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _isRecording
                ? 'Tap the microphone to stop'
                : 'Say your state, the product, materials, and how many hours it took',

            textAlign: TextAlign.center,

            style: const TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 24),

          if (_isTranscribing)
            const Column(
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF1E7A4C),
                ),

                SizedBox(height: 12),

                Text(
                  'Converting your voice to text...',
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),


          if (_isGenerating)
            const Column(
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF1E7A4C),
                ),

                SizedBox(height: 12),

                Text(
                  'AI is creating your listing and calculating price...',
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),


          // Whisper text
          if (_transcribedText.isNotEmpty &&
              !_isGenerating) ...[
            const Align(
              alignment: Alignment.centerLeft,

              child: Text(
                'What you said',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            _InfoBox(
              text: _transcribedText,
            ),

            const SizedBox(height: 20),
          ],


          // AI result
          if (result != null) ...[
            const Align(
              alignment: Alignment.centerLeft,

              child: Text(
                '✨ AI-generated product listing',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            _InfoCard(
              title: 'Product Title',
              value: result.title,
              icon: Icons.title,
            ),

            _InfoCard(
              title: 'Description',
              value: result.description,
              icon: Icons.description_outlined,
            ),

            _InfoCard(
              title: 'Materials',
              value: result.materials,
              icon: Icons.handyman_outlined,
            ),

            _InfoCard(
              title: 'Category',
              value: result.category,
              icon: Icons.category_outlined,
            ),

            if (result.tags.isNotEmpty)
              Container(
                width: double.infinity,

                padding:
                    const EdgeInsets.all(16),

                margin:
                    const EdgeInsets.only(
                  bottom: 12,
                ),

                decoration:
                    BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(12),

                  border:
                      Border.all(
                    color: Colors.black12,
                  ),
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Tags',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,

                      children:
                          result.tags.map(
                        (tag) {
                          return Chip(
                            label:
                                Text(tag),

                            backgroundColor:
                                const Color(
                              0xFFE9F5EC,
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Cost breakdown, extracted straight from voice.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F5EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What we understood',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _KeyValueRow('State', result.state),
                  _KeyValueRow('Product size', result.productSize),
                  _KeyValueRow(
                    'Labour',
                    '${result.labourHours.toStringAsFixed(0)} hrs × ₹${result.labourRate.toStringAsFixed(0)}/hr = ₹${result.labourCost.toStringAsFixed(0)}',
                  ),
                  _KeyValueRow(
                    'Material cost',
                    '₹${result.materialCost.toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Suggested price: ₹${result.predictedPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E7A4C),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],


          if (_error != null) ...[
            const SizedBox(height: 8),

            Text(
              _error!,
              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                color: Colors.red,
              ),
            ),
          ],


          const SizedBox(height: 20),


          // Continue
          if (!_isRecording &&
              !_isTranscribing &&
              !_isGenerating)
            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed:
                    (result != null && result.title.isNotEmpty)
                        ? _continue
                        : null,

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF1E7A4C,
                  ),

                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 16,
                  ),

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),

                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}


// ============================================================
// KEY-VALUE ROW (small helper for the cost breakdown)
// ============================================================

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// INFO BOX
// ============================================================

class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(12),

        border:
            Border.all(
          color: Colors.black12,
        ),
      ),

      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
        ),
      ),
    );
  }
}


// ============================================================
// INFO CARD
// ============================================================

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(12),

        border:
            Border.all(
          color: Colors.black12,
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            color:
                const Color(0xFF1E7A4C),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  value,
                  style:
                      const TextStyle(
                    color:
                        Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// STEP 3: PRICE
// ============================================================
// No longer collects manual input on load — it's pre-filled
// with everything Gemini extracted from the artisan's voice.
// The artisan can still adjust fields and recalculate if the
// AI got something wrong.

class _PriceStep extends StatefulWidget {
  final double initialPrice;
  final String state;
  final String region;
  final String category;
  final String material;
  final double materialCost;
  final double labourCost;
  final double labourHours;
  final String productSize;
  final int complexity;
  final double currentMarketPrice;
  final double demandScore;

  final ValueChanged<double> onNext;

  const _PriceStep({
    required this.initialPrice,
    required this.state,
    required this.region,
    required this.category,
    required this.material,
    required this.materialCost,
    required this.labourCost,
    required this.labourHours,
    required this.productSize,
    required this.complexity,
    required this.currentMarketPrice,
    required this.demandScore,
    required this.onNext,
  });

  @override
  State<_PriceStep> createState() => _PriceStepState();
}

class _PriceStepState extends State<_PriceStep> {
  late final _materialCostController =
      TextEditingController(text: widget.materialCost.toStringAsFixed(0));
  late final _labourCostController =
      TextEditingController(text: widget.labourCost.toStringAsFixed(0));
  late final _labourHoursController =
      TextEditingController(text: widget.labourHours.toStringAsFixed(0));
  late final _marketPriceController = TextEditingController(
      text: widget.currentMarketPrice.toStringAsFixed(0));

  late String _selectedState = widget.state;
  late String _selectedSize = widget.productSize;

  double? _predictedPrice;
  bool _loading = false;
  String? _error;

  final List<String> _states = [
    'Karnataka', 'Tamil Nadu', 'Kerala', 'Andhra Pradesh', 'Telangana',
    'Rajasthan', 'Gujarat', 'Maharashtra', 'West Bengal', 'Odisha',
    'Uttar Pradesh', 'Madhya Pradesh', 'Punjab', 'Assam',
  ];

  final Map<String, String> _stateToRegion = {
    'Karnataka': 'South', 'Tamil Nadu': 'South', 'Kerala': 'South',
    'Andhra Pradesh': 'South', 'Telangana': 'South',
    'Rajasthan': 'West', 'Gujarat': 'West', 'Maharashtra': 'West',
    'West Bengal': 'East', 'Odisha': 'East',
    'Uttar Pradesh': 'North', 'Madhya Pradesh': 'Central',
    'Punjab': 'North', 'Assam': 'Northeast',
  };

  Future<void> _calculatePrice() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final materialCost = double.tryParse(_materialCostController.text) ?? 0;
    final labourCost = double.tryParse(_labourCostController.text) ?? 0;
    final labourHours = double.tryParse(_labourHoursController.text) ?? 0;
    final marketPrice = double.tryParse(_marketPriceController.text) ?? 0;

    // Ensure a valid state key, since our dropdown list may not
    // contain whatever Gemini returned verbatim.
    final stateKey =
        _states.contains(_selectedState) ? _selectedState : _states.first;

    final result = await PricingService.predictPrice(
      state: stateKey,
      region: _stateToRegion[stateKey] ?? 'South',
      craftCategory: widget.category,
      material: widget.material,
      materialCost: materialCost,
      labourCost: labourCost,
      labourHours: labourHours,
      productSize: _selectedSize,
      complexity: widget.complexity,
      currentMarketPrice: marketPrice,
      demandScore: widget.demandScore,
      seasonScore: 0.6,
    );

    setState(() {
      _loading = false;
      if (result != null) {
        _predictedPrice = result;
      } else {
        _error = 'Could not calculate price. Check your connection and try again.';
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // The AI already computed a price during the Details step
    // (widget.initialPrice) — show it immediately instead of
    // making the artisan wait for another network call.
    _predictedPrice = widget.initialPrice;

    if (!_states.contains(_selectedState)) {
      _selectedState = _states.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggested Price',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F5EC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red))
                else
                  Text(
                    '₹${_predictedPrice?.toStringAsFixed(0) ?? '--'}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E7A4C),
                    ),
                  ),
                const Text(
                  '(Recommended, based on what you said)',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Cost details (from your voice — adjust if needed)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            initialValue: _selectedState,
            decoration: const InputDecoration(labelText: 'State'),
            items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _selectedState = v ?? _selectedState),
          ),

          DropdownButtonFormField<String>(
            initialValue: _selectedSize,
            decoration: const InputDecoration(labelText: 'Product size'),
            items: ['Small', 'Medium', 'Large']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedSize = v ?? _selectedSize),
          ),

          TextField(
            controller: _materialCostController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Material cost (₹)'),
          ),

          TextField(
            controller: _labourCostController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Labour cost (₹)'),
          ),

          TextField(
            controller: _labourHoursController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Labour hours'),
          ),

          TextField(
            controller: _marketPriceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Similar market price (₹)'),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading ? null : _calculatePrice,
              child: const Text('Recalculate Price'),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _predictedPrice == null
                  ? null
                  : () => widget.onNext(_predictedPrice!),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E7A4C),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _predictedPrice == null
                    ? 'Use this price'
                    : 'Use ₹${_predictedPrice!.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}


// ============================================================
// STEP 4: DONE
// ============================================================

class _DoneStep extends StatelessWidget {
  final String title;
  final String price;
  final Uint8List? image;
  final List<String> tags;

  final VoidCallback onViewProduct;
  final VoidCallback onAddAnother;

  const _DoneStep({
    required this.title,
    required this.price,
    required this.image,
    required this.tags,
    required this.onViewProduct,
    required this.onAddAnother,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
      ),

      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          const SizedBox(height: 20),

          const Icon(
            Icons.celebration,
            size: 56,
            color:
                Color(0xFF1E7A4C),
          ),

          const SizedBox(height: 12),

          const Text(
            'Your product is ready!',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,

            padding:
                const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius:
                  BorderRadius.circular(16),

              border:
                  Border.all(
                color: Colors.black12,
              ),
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                if (image != null)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(12),

                    child: Image.memory(
                      image!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Container(
                    height: 140,

                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFFBEDE4),

                      borderRadius:
                          BorderRadius.circular(12),
                    ),

                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 40,
                        color:
                            Colors.black26,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                Text(
                  title,

                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                Text(
                  price,

                  style:
                      const TextStyle(
                    color:
                        Color(0xFF1E7A4C),
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,

                    children:
                        tags.take(5).map(
                      (tag) {
                        return Chip(
                          label:
                              Text(tag),

                          backgroundColor:
                              const Color(
                            0xFFE9F5EC,
                          ),
                        );
                      },
                    ).toList(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Your product is now ready for the marketplace.',
            style: TextStyle(
              color:
                  Colors.black54,
            ),

            textAlign:
                TextAlign.center,
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,

            child: ElevatedButton(
              onPressed:
                  onViewProduct,

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF1E7A4C),

                padding:
                    const EdgeInsets.symmetric(
                  vertical: 16,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),

              child: const Text(
                'View Product',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,

            child: OutlinedButton(
              onPressed:
                  onAddAnother,

              style:
                  OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 16,
                ),
              ),

              child: const Text(
                'Add Another Product',
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}