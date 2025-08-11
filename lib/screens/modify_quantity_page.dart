import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModifyQuantityPage extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;

  const ModifyQuantityPage({
    Key? key,
    required this.itemId,
    required this.itemData,
  }) : super(key: key);

  @override
  _ModifyQuantityPageState createState() => _ModifyQuantityPageState();
}

class _ModifyQuantityPageState extends State<ModifyQuantityPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _reasonController;
  String? _selectedTeam;

  @override
  void initState() {
    super.initState();
    final data = widget.itemData;

    _nameController = TextEditingController(
      text: data['name']?.toString() ?? '',
    );
    _locationController = TextEditingController(
      text: data['location']?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: data['quantity']?.toString() ?? '0',
    );
    _priceController = TextEditingController(
      text: data['price']?.toString() ?? '0.0',
    );
    _reasonController = TextEditingController();
    _selectedTeam = data['teamname']?.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'unknown';
    final userEmail = user?.email ?? 'unknown@example.com';

    final newQuantity = int.parse(_quantityController.text.trim());
    final oldQuantity = widget.itemData['quantity'] as int? ?? 0;

    final updateData = {
      'name': _nameController.text.trim(),
      'location': _locationController.text.trim(),
      'quantity': newQuantity,
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'teamname': _selectedTeam ?? '',
    };

    final firestore = FirebaseFirestore.instance;
    final itemRef = firestore.collection('items').doc(widget.itemId);

    final batch = firestore.batch();
    batch.update(itemRef, updateData);

    if (oldQuantity != newQuantity) {
      final adjustmentRef = firestore.collection('adjustments').doc();
      batch.set(adjustmentRef, {
        'itemId': widget.itemId,
        'itemName': _nameController.text.trim(),
        'oldQuantity': oldQuantity,
        'newQuantity': newQuantity,
        'reason': _reasonController.text.trim(),
        'modifiedBy': uid,
        'modifiedByEmail': userEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Item updated successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error updating item: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text(
              'Are you sure you want to delete this item? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('items')
            .doc(widget.itemId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('🗑️ Item deleted.')));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ Error deleting item: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF4F6FD);
    const primaryColor = Color.fromARGB(255, 0, 183, 255);
    const textColor = Color(0xFF212121);
    const accentColor = Color(0xFF00ACC1);

    InputDecoration _decor(String label, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: textColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Modify Item'),
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _decor('Item Name'),
                validator:
                    (val) =>
                        val == null || val.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: _decor('Location'),
                validator:
                    (val) =>
                        val == null || val.trim().isEmpty
                            ? 'Enter location'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: _decor('Quantity'),
                keyboardType: TextInputType.number,
                validator: (val) {
                  final parsed = int.tryParse(val ?? '');
                  if (parsed == null || parsed < 0)
                    return 'Enter valid quantity';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: _decor('Price'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  final parsed = double.tryParse(val ?? '');
                  if (parsed == null || parsed < 0) return 'Enter valid price';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTeam,
                decoration: _decor('Team Name'),
                items: const [
                  DropdownMenuItem(value: 'NI', child: Text('NI')),
                  DropdownMenuItem(
                    value: 'FRC Mechanical',
                    child: Text('FRC Mechanical'),
                  ),
                  DropdownMenuItem(
                    value: 'FRC Electronics',
                    child: Text('FRC Electronics'),
                  ),
                  DropdownMenuItem(
                    value: 'FTC Mechanical',
                    child: Text('FTC Mechanical'),
                  ),
                  DropdownMenuItem(
                    value: 'FTC Electronics',
                    child: Text('FTC Electronics'),
                  ),
                  DropdownMenuItem(value: 'WRO', child: Text('WRO')),
                  DropdownMenuItem(value: 'Others', child: Text('OTHERS')),
                ],
                onChanged: (value) {
                  setState(() => _selectedTeam = value);
                },
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Please select a team'
                            : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: _decor('Reason for Change*'),
                maxLines: 2,
                // validator:
                //     (val) =>
                //         val == null || val.trim().isEmpty
                //             ? 'Please provide a reason'
                //             : null,
              ),

              const SizedBox(height: 24),
              if (_isSaving)
                const CircularProgressIndicator()
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saveChanges,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Delete Item',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _deleteItem,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
