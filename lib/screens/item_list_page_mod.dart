import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/screens/modify_quantity_page.dart';

class ItemListPage extends StatefulWidget {
  const ItemListPage({Key? key}) : super(key: key);

  @override
  State<ItemListPage> createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
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
    const Color cardColor = Colors.white;
    const Color iconColor = Color(0xFF3949AB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('All Items'),
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('items')
                .orderBy('name')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No items found.'));
          }

          final docs = snapshot.data!.docs;

          // Filter using search query
          final filteredDocs =
              docs.where((doc) {
                final name = doc.data()['name']?.toString().toLowerCase() ?? '';
                return name.contains(_searchQuery);
              }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(child: Text('No matching items.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data();
              final name = data['name']?.toString() ?? 'Unnamed';
              final qty =
                  int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;

              return Card(
                color: cardColor,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: const Icon(Icons.widgets_outlined, color: iconColor),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'Quantity: $qty',
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: const Icon(Icons.edit, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ModifyQuantityPage(
                              itemId: doc.id,
                              itemData: data,
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
