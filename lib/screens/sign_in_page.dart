import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'sign_up_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'forgotpassword.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showErrorDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE53E3E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFE53E3E),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign In Failed',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        content: Text(
          'Invalid email or password. Please check your credentials and try again.',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 16,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (Navigator.canPop(context)) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAccessDeniedDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF7043).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Color(0xFFFF7043),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Access Pending',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        content: Text(
          'Your account is pending administrator approval. You will receive access once your account has been reviewed and approved.',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 16,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7043),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Understood',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // Sign in using AuthService
      await context.read<AuthService>().signIn(
        email: email,
        password: password,
        role: '',
      );

      if (!mounted) return;

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final usersRef = FirebaseFirestore.instance.collection('users');

      // Try UID-based document first
      DocumentSnapshot<Map<String, dynamic>> doc = await usersRef.doc(uid).get();

      // Fallback to email-based document for old data
      if (!doc.exists) {
        doc = await usersRef.doc(email).get();
      }

      if (!doc.exists) {
        // No user record found
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        await _showAccessDeniedDialog();
        return;
      }

      final data = doc.data()!;
      final role = data['role'] ?? '';
      final team = data['team'] ?? '';
      final status = data['status'] ?? 'approved'; // Default to approved if null

      // Block only if not admin and status explicitly not approved
      if (role != 'admin' && status != 'approved') {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        await _showAccessDeniedDialog();
        return;
      }

      // ✅ Passed checks — proceed
      print('Role: $role, Team: $team');
    } on FirebaseAuthException {
      if (!mounted) return;
      await _showErrorDialog();
    } catch (_) {
      if (!mounted) return;
      await _showErrorDialog();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Flexible(
                    fit: FlexFit.tight,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 32),
                            _buildSignInForm(),
                            const SizedBox(height: 24),
                            _buildSignInButton(),
                            const SizedBox(height: 24),
                            _buildNavigationLinks(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1565C0),
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Inventory System',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1565C0),
                Color(0xFF0D47A1),
              ],
            ),
          ),
        ),
      ),
    );
  }
Widget _buildHeader() {
  return Column(
    children: [
      // Rectangular logo with drop shadow
      Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Image.asset(
          'assets/TIS Logo without background.png',
          width: 160, // adjust for your layout
          fit: BoxFit.contain,
        ),
      ),

      const SizedBox(height: 20),

      const Text(
        'Welcome Back',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2C3E50),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Sign in to access your inventory dashboard',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );
}

  Widget _buildSignInForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              obscureText: _obscurePassword,
              onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool? obscureText,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText ?? false,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText! ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: const Color(0xFF1565C0),
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: _isLoading
          ? Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
                ),
              ),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                shadowColor: const Color(0xFF1565C0).withOpacity(0.3),
              ),
              onPressed: _signIn,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.login_rounded, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNavigationLinks() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        children: [
          // Forgot Password Link
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ForgotPasswordPage(),
                ),
              );
            },
            child: const Text(
              'Forgot your password?',
              style: TextStyle(
                color: Color(0xFF1565C0),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'New to the system?',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Sign Up Link
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SignUpPage(),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 20,
                  color: Color(0xFF1565C0),
                ),
                SizedBox(width: 12),
                Text(
                  'Create New Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0),
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