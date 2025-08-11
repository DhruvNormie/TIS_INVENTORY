import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddLaptopPage extends StatefulWidget {
  const AddLaptopPage({Key? key}) : super(key: key);

  @override
  _AddLaptopPageState createState() => _AddLaptopPageState();
}

class _AddLaptopPageState extends State<AddLaptopPage> {
  final _formKey = GlobalKey<FormState>();
  String _laptopName = '';

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      await FirebaseFirestore.instance.collection('laptops').add({
        'name': _laptopName,
        'createdAt': Timestamp.now(),
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF4F6FD);
    const Color primaryColor = Color.fromARGB(255, 0, 183, 255);
    const Color textColor = Color(0xFF212121);
    const Color buttonColor = Color(0xFF00ACC1); // accent

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Add New Laptop'),
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Laptop Name',
                  filled: true,
                  fillColor: Colors.white,
                  labelStyle: const TextStyle(color: textColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                validator:
                    (val) =>
                        val == null || val.trim().isEmpty ? 'Required' : null,
                onSaved: (val) => _laptopName = val!.trim(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Add Laptop',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
