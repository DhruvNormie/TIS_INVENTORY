import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/screens/confirmation_page.dart';

class ReturnablePage extends StatefulWidget {
  const ReturnablePage({Key? key}) : super(key: key);

  @override
  _ReturnablePageState createState() => _ReturnablePageState();
}

class _ReturnablePageState extends State<ReturnablePage> {
  final _remarkController = TextEditingController();
  final _reasonController = TextEditingController();
  String _search = '';
  Map<String, int> _selected = {};
  String? _selectedTeam;
  List<String> _teams = [];

  @override
  void dispose() {
    _remarkController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  bool get _canPlace =>
      _remarkController.text.trim().isNotEmpty &&
      _reasonController.text.trim().isNotEmpty &&
      _selected.values.any((q) => q > 0);

  void _placeOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmationPage(
       //   userName: FirebaseAuth.instance.currentUser?.email ?? 'Unknown User',
          isReturnable: true,
          remark: _remarkController.text.trim(),
          reason: _reasonController.text.trim(),
          items: Map.fromEntries(
            _selected.entries.where((e) => e.value > 0),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _remarkController.addListener(() => setState(() {}));
    _reasonController.addListener(() => setState(() {}));

    FirebaseFirestore.instance.collection('items').get().then((snapshot) {
      final teamSet = <String>{};
      for (var doc in snapshot.docs) {
        final team = doc['teamname']?.toString();
        if (team != null && team.isNotEmpty) {
          teamSet.add(team);
        }
      }
      setState(() {
        _teams = teamSet.toList()..sort();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF4F6FD);
    const Color primaryColor = Color.fromARGB(255, 0, 183, 255);
    const Color iconColor = Color(0xFF3949AB);
    const Color textColor = Color(0xFF212121);
    const Color accentColor = Color(0xFF00ACC1);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Borrow Returnable Items'),
        centerTitle: true,
        elevation: 4,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Remark Field
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _remarkController,
                    decoration: InputDecoration(
                      labelText: 'Enter Remark',
                      labelStyle: TextStyle(color: iconColor),
                      prefixIcon: Icon(Icons.comment_outlined, color: iconColor),
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: accentColor, width: 2),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Reason for Issue Field
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _reasonController,
                    decoration: InputDecoration(
                      labelText: 'Reason for Issue',
                      labelStyle: TextStyle(color: iconColor),
                      prefixIcon: Icon(Icons.help_outline, color: iconColor),
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: accentColor, width: 2),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Search Field
              Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search items',
                      labelStyle: TextStyle(color: iconColor),
                      prefixIcon: Icon(Icons.search_outlined, color: iconColor),
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: accentColor, width: 2),
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v.trim()),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Team Filter Dropdown
              if (_teams.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Filter by Team',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.group),
                    ),
                    value: _selectedTeam,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Teams'),
                      ),
                      ..._teams.map(
                        (team) =>
                            DropdownMenuItem(value: team, child: Text(team)),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedTeam = value),
                  ),
                ),

              // Items List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('items').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;

                    final filtered = docs.where((d) {
                      final name = d['name']?.toString().toLowerCase() ?? '';
                      final team = d['teamname']?.toString();
                      final matchesSearch = name.contains(_search.toLowerCase());
                      final matchesTeam = _selectedTeam == null || team == _selectedTeam;
                      return matchesSearch && matchesTeam;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'No items found',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final d = filtered[index];
                        final id = d.id;
                        final name = d['name']?.toString() ?? 'Unnamed';
                       final available = d['totalQuantity'] ?? 0;

                        final selected = _selected[id] ?? 0;
                        final team = d['teamname']?.toString() ?? 'Unknown';

                        return Card(
                          color: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Available: $available',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Team: $team',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.remove_circle_outline,
                                        color: selected > 0
                                            ? accentColor
                                            : Colors.grey.shade400,
                                      ),
                                      onPressed: selected > 0
                                          ? () => setState(() => _selected[id] = selected - 1)
                                          : null,
                                    ),
                                    Text(
                                      '$selected',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.add_circle_outline,
                                        color: selected < available
                                            ? accentColor
                                            : Colors.grey.shade400,
                                      ),
                                      onPressed: selected < available
                                          ? () => setState(() => _selected[id] = selected + 1)
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Place Order Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canPlace ? accentColor : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _canPlace ? _placeOrder : null,
                  child: const Text(
                    'Place Order',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
