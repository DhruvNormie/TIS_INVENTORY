import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/item_service.dart';

class AddItemPage extends StatefulWidget {
  const AddItemPage({Key? key}) : super(key: key);

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  String? _selectedBranch;
  String? _selectedTeam;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final name = _nameController.text.trim();
      final teamname = _selectedTeam ?? '';
      final branch = _selectedBranch ?? '';
      final location = _locationController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final quantity = int.parse(_quantityController.text.trim());

      if (name.isEmpty || teamname.isEmpty || branch.isEmpty) {
        throw Exception("Please fill all required fields.");
      }

      final itemsCollection = FirebaseFirestore.instance.collection('items');

      // Check if item already exists
      final existingItemQuery = await itemsCollection
          .where('name', isEqualTo: name)
          .where('teamname', isEqualTo: teamname)
          .where('branch', isEqualTo: branch)
          .limit(1)
          .get();

      if (existingItemQuery.docs.isNotEmpty) {
        // Existing item — add a new batch and update totalQuantity
        final existingDoc = existingItemQuery.docs.first;
        final itemRef = existingDoc.reference;
        final batchesCollection = itemRef.collection('batches');

        final batchWrite = FirebaseFirestore.instance.batch();

        // Create new batch doc WITH price
        final newBatchRef = batchesCollection.doc();
        batchWrite.set(newBatchRef, {
          'quantity': quantity,
          'price': price, // <-- Store price per batch here
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update totalQuantity and latest price on item doc
        final currentTotalQuantity = existingDoc['totalQuantity'] ?? 0;
        batchWrite.update(itemRef, {
          'totalQuantity': currentTotalQuantity + quantity,
          'price': price,  // <-- latest/current price on item doc (optional)
          'location': location,
          'branch': branch,
        });

        await batchWrite.commit();
      } else {
        // New item — create item doc with totalQuantity, and create first batch
        final newItemRef = await itemsCollection.add({
          'name': name,
          'teamname': teamname,
          'branch': branch,
          'location': location,
          'price': price,
          'totalQuantity': quantity,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Create initial batch WITH price
        await newItemRef.collection('batches').add({
          'quantity': quantity,
          'price': price, // <-- Store price per batch here
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF4F6FD);
    const Color primaryColor = Color.fromARGB(255, 0, 183, 255);
    const Color textColor = Color(0xFF212121);
    const Color accentColor = Color(0xFF00ACC1);

    InputDecoration _inputDecoration(String label) {
      return InputDecoration(
        labelText: label,
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
        title: const Text('Add New Item'),
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration('Component Name'),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedTeam,
              decoration: _inputDecoration('Team Name'),
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
                setState(() {
                  _selectedTeam = value;
                });
              },
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: _inputDecoration('Location / Box Name'),
            ),

            DropdownButtonFormField<String>(
              value: _selectedBranch,
              decoration: _inputDecoration('Branch'),
              items: const [
                DropdownMenuItem(value: 'Dadar', child: Text('Dadar')),
                DropdownMenuItem(value: 'Bandra', child: Text('Bandra')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedBranch = value;
                });
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Unit Value (e.g. 9.99)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Live Inventory Quantity'),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Save Item',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      onPressed: _saveItem,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
