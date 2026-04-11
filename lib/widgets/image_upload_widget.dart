import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/image_upload_service.dart';

class ImageUploadWidget extends StatefulWidget {
  final String? initialImageUrl;
  final String? initialImagePublicId;
  final Function(String?, String?) onImageSelected;
  final double height;
  final double width;

  const ImageUploadWidget({
    super.key,
    this.initialImageUrl,
    this.initialImagePublicId,
    required this.onImageSelected,
    this.height = 200,
    this.width = double.infinity,
  });

  @override
  _ImageUploadWidgetState createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  String? _imageUrl;
  String? _imagePublicId;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
    _imagePublicId = widget.initialImagePublicId;
  }

  Future<void> _pickAndUploadImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'PNG', 'jpg', 'JPG', 'jpeg', 'JPEG', 'gif', 'GIF', 'webp', 'WEBP'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isUploading = true);

        final uploadResult = await ImageUploadService.uploadImage(result.files.first);
        if (uploadResult == null) {
          throw Exception('Upload service returned null');
        }

        setState(() {
          _isUploading = false;
          _imageUrl = uploadResult['url'];
          _imagePublicId = uploadResult['publicId'];
        });

        widget.onImageSelected(_imageUrl, _imagePublicId);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    // If there's a publicId, delete from cloudinary
    if (_imagePublicId != null) {
      await ImageUploadService.deleteImage(_imagePublicId!);
    }
    setState(() {
      _imageUrl = null;
      _imagePublicId = null;
    });
    widget.onImageSelected(null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _imageUrl != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _imageUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _removeImage,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: _isUploading ? null : _pickAndUploadImage,
                  child: Center(
                    child: _isUploading
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text('Tap to upload image'),
                            ],
                          ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _pickAndUploadImage,
          icon: _isUploading ? const SizedBox.shrink() : const Icon(Icons.upload),
          label: Text(_isUploading ? 'Uploading...' : 'Change Image'),
        ),
      ],
    );
  }
}