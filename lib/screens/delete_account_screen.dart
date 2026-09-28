import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const String _pendingKey = 'delete_account_pending';
  bool _isPending = false;

  @override
  void initState() {
    super.initState();
    _checkPendingStatus();
  }

  Future<void> _checkPendingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isPending = prefs.getBool(_pendingKey) ?? false;
    });
  }

  Future<void> _submitDeleteRequest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, true);
    if (!mounted) return;
    setState(() {
      _isPending = true;
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Submitted'),
        content: const Text(
            'Your account deletion request has been submitted. You will be notified upon deletion.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingScreen() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top, size: 64, color: Colors.orange),
            SizedBox(height: 24),
            Text(
              'Deletion Request Pending',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Your account deletion request is pending. You will be notified once your account is deleted.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_forever, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Delete Account',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _submitDeleteRequest,
              child: const Text('Submit Delete Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
      ),
      body: _isPending ? _buildPendingScreen() : _buildDeleteScreen(),
    );
  }
}
