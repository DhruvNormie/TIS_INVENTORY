import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class OTPVerificationPage extends StatefulWidget {
  final String email;
  final String password;
  final String role;

  const OTPVerificationPage({
    Key? key,
    required this.email,
    required this.password,
    required this.role,
  }) : super(key: key);

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;

  Future<void> _verifyOTP() async {
    final enteredOTP = _otpController.text.trim();

    if (enteredOTP.isEmpty) {
      _showMessage("Please enter the OTP.");
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('otp_verifications')
              .doc(widget.email)
              .get();

      if (!doc.exists) {
        _showMessage("OTP not found. Please try signing up again.");
        return;
      }

      final storedOTP = doc.data()?['otp'];

      if (storedOTP == enteredOTP) {
        // OTP verified, proceed to create user
        await context.read<AuthService>().signUp(
          email: widget.email,
          password: widget.password,
          role: widget.role,
        );

        // Delete OTP after successful verification
        await FirebaseFirestore.instance
            .collection('otp_verifications')
            .doc(widget.email)
            .delete();

        _showMessage("Signup successful!", isError: false);
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showMessage("Invalid OTP. Please try again.");
      }
    } catch (e) {
      _showMessage("Something went wrong. Please try again.");
      print("OTP Verification Error: $e");
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF00ACC1);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify OTP"),
        backgroundColor: accentColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Enter the 6-digit OTP sent to your email",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'OTP',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.security),
              ),
            ),
            const SizedBox(height: 24),
            _isVerifying
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Verify & Sign Up",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
