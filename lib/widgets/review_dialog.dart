import 'package:flutter/material.dart';

class ReviewDialog extends StatefulWidget {
  final VoidCallback onDismiss;
  final void Function(String text, double costumeRating, double storeRating) onSubmit;

  const ReviewDialog({super.key, required this.onDismiss, required this.onSubmit});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final _textController = TextEditingController();
  double _costumeRating = 5;
  double _storeRating = 5;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Write a Review', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Review',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text('Costume Rating: ${_costumeRating.toInt()}/5'),
            Slider(
              value: _costumeRating,
              onChanged: (v) => setState(() => _costumeRating = v),
              min: 1,
              max: 5,
              divisions: 4,
            ),
            const SizedBox(height: 8),
            Text('Store Rating: ${_storeRating.toInt()}/5'),
            Slider(
              value: _storeRating,
              onChanged: (v) => setState(() => _storeRating = v),
              min: 1,
              max: 5,
              divisions: 4,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onDismiss,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _textController.text.trim().isEmpty
                      ? null
                      : () {
                          widget.onSubmit(
                            _textController.text.trim(),
                            _costumeRating,
                            _storeRating,
                          );
                          widget.onDismiss();
                        },
                  child: const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
