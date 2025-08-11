import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_borrowers_page.dart';

class TeamDetailPage extends StatefulWidget {
  final String teamname;
  const TeamDetailPage({Key? key, required this.teamname}) : super(key: key);

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF4F6FD);
    const Color primaryColor = Color.fromARGB(255, 0, 183, 255);
    const Color textColor = Color(0xFF212121);
    const Color cardColor = Colors.white;
    const Color iconColor = Color(0xFF3949AB);
    const Color accentColor = Color(0xFF00ACC1);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text('Items for ${widget.teamname}'),
        centerTitle: true,
        elevation: 4,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('items')
                .where('teamname', isEqualTo: widget.teamname)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data!.docs;

          // Filter items by search
          final filteredDocs =
              docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name']?.toString().toLowerCase() ?? '';

                // final name = (data['name'] as String?)?.toLowerCase() ?? '';
                return name.contains(_searchQuery);
              }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text('No matching items found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name']?.toString() ?? 'Unnamed';

              final quantity = (data['quantity'] as int?) ?? 0;
              final itemId = doc.id;

              return Card(
                color: cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  leading: const Icon(Icons.widgets_outlined, color: iconColor),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    'Location: ${data['location'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  trailing: Text(
                    'Qty: $quantity',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ItemBorrowersPage(
                              itemId: itemId,
                              itemName: name,
                            ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
