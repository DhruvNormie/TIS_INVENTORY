import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/screens/confirmation_page.dart';

class NonReturnablePage extends StatefulWidget {
  const NonReturnablePage({Key? key}) : super(key: key);

  @override
  _NonReturnablePageState createState() => _NonReturnablePageState();
}

class _NonReturnablePageState extends State<NonReturnablePage> {
  final _studentController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _selectedTeam;
  List<String> _teams = [];

  String _search = '';
  Map<String, int> _selected = {};
  @override
  void initState() {
    super.initState();

    // Fetch unique team names
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
  void dispose() {
    _studentController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  bool get _canPlace =>
      _studentController.text.trim().isNotEmpty &&
      _reasonController.text.trim().isNotEmpty &&
      _selected.values.any((q) => q > 0);

  void _placeOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ConfirmationPage(
              isReturnable: false,
             // userName: _studentController.text.trim(),
              reason: _reasonController.text.trim(),
              items: Map.fromEntries(
                _selected.entries.where((e) => e.value > 0),
              ), remark: '',
            ),
      ),
    );
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Issue Non-Returnable Items'),
        centerTitle: true,
        elevation: 4,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Student Name
                      _buildInputCard(
                        controller: _studentController,
                        label: 'Enter Remark',
                        icon: Icons.person_outline,
                        iconColor: iconColor,
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 12),

                      // Reason
                      _buildInputCard(
                        controller: _reasonController,
                        label: 'Reason for issue',
                        icon: Icons.description_outlined,
                        iconColor: iconColor,
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 12),

                      // Search
                      _buildInputCard(
                        onChanged: (v) => setState(() => _search = v.trim()),
                        label: 'Search items',
                        icon: Icons.search_outlined,
                        iconColor: iconColor,
                        accentColor: accentColor,
                      ),
                      const SizedBox(height: 16),
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
                                (team) => DropdownMenuItem(
                                  value: team,
                                  child: Text(team),
                                ),
                              ),
                            ],
                            onChanged:
                                (value) =>
                                    setState(() => _selectedTeam = value),
                          ),
                        ),

                      // Item list
                      SizedBox(
                        height: 300, // fixed height for scrollable item list
                        child: StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('items')
                                  .snapshots(),
                          builder: (context, snap) {
                            if (!snap.hasData)
                              return const Center(
                                child: CircularProgressIndicator(),
                              );

                            final docs = snap.data!.docs;
                            final filtered =
                                docs.where((d) {
                                  final name =
                                      d['name']?.toString().toLowerCase() ?? '';
                                  final team = d['teamname']?.toString();
                                  final matchesSearch = name.contains(
                                    _search.toLowerCase(),
                                  );
                                  final matchesTeam =
                                      _selectedTeam == null ||
                                      _selectedTeam == 'All Teams' ||
                                      team == _selectedTeam;
                                  return matchesSearch && matchesTeam;
                                }).toList();

                            if (filtered.isEmpty) {
                              return const Center(
                                child: Text('No items found'),
                              );
                            }

                            return ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final d = filtered[index];
                                final id = d.id;
                                final name = d['name'] ?? 'Unnamed';
                                final available = d['totalQuantity'] ?? 0;

                                final selected = _selected[id] ?? 0;
                                final team =
                                    d['teamname']?.toString() ?? 'Unknown';

                                return Card(
                                  color: Colors.white,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name.toString(),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
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
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.remove_circle_outline,
                                                color:
                                                    selected > 0
                                                        ? accentColor
                                                        : Colors.grey.shade400,
                                              ),
                                              onPressed:
                                                  selected > 0
                                                      ? () => setState(
                                                        () =>
                                                            _selected[id] =
                                                                selected - 1,
                                                      )
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
                                                color:
                                                    selected < available
                                                        ? accentColor
                                                        : Colors.grey.shade400,
                                              ),
                                              onPressed:
                                                  selected < available
                                                      ? () => setState(
                                                        () =>
                                                            _selected[id] =
                                                                selected + 1,
                                                      )
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

                      const SizedBox(height: 20),

                      // Place Order
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _canPlace ? accentColor : Colors.grey.shade400,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color accentColor,
    TextEditingController? controller,
    Function(String)? onChanged,
  }) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: iconColor),
            prefixIcon: Icon(icon, color: iconColor),
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
    );
  }
}
