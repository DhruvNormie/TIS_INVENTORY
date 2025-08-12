import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/transaction_service.dart';

class ConfirmationPage extends StatefulWidget {
  final bool isReturnable;
  final String remark;
  final String? reason;
  final Map<String, int> items;
  
  const ConfirmationPage({
    Key? key,
    required this.isReturnable,
    required this.remark,
 
    this.reason,
    required this.items,
  }) : super(key: key);

  @override
  _ConfirmationPageState createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  bool _processing = false;
  String? _error;
Future<void> _confirm() async {
  setState(() {
    _processing = true;
    _error = null;
  });

  try {
    await TransactionService().createTransactionPending(
      isReturnable: widget.isReturnable,
      remark: widget.remark,
      reason: widget.reason,
      items: widget.items,
    );

    if (!mounted) return;

    // Show success message that it's waiting for manager approval
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Submitted'),
        content: const Text(
          'Your request has been sent to your manager for approval. You will be notified once it is reviewed.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } catch (e) {
    setState(() => _error = e.toString());
  } finally {
    if (mounted) setState(() => _processing = false);
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Order')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Name: ${widget.remark}'),
            if (!widget.isReturnable && widget.reason != null)
              Text('Reason: ${widget.reason}'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children:
                    widget.items.entries.map((entry) {
                      final itemId = entry.key;
                      final qty = entry.value;
                      return FutureBuilder<DocumentSnapshot>(
                        future:
                            FirebaseFirestore.instance
                                .collection('items')
                                .doc(itemId)
                                .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('Loading item...'),
                            );
                          }
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return ListTile(
                              title: const Text('Item not found'),
                              trailing: Text('Qty: $qty'),
                            );
                          }
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final itemName = data['name'] as String? ?? 'Unnamed';
                          return ListTile(
                            title: Text(itemName),
                            trailing: Text('Qty: $qty'),
                          );
                        },
                      );
                    }).toList(),
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            _processing
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                  onPressed: _confirm,
                  child: const Text('Confirm'),
                ),
          ],
        ),
      ),
    );
  }
}
