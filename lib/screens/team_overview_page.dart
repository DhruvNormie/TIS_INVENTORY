import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'team_detail_page.dart';

/// Admin page to view inventory grouped by teamname
class TeamOverviewPage extends StatelessWidget {
  const TeamOverviewPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color cardColor = Color(0xFFF4F6FD);
    const Color titleColor = Color(0xFF212121);
    const Color subtitleColor = Color(0xFF607D8B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Inventory Overview'),
        backgroundColor: Color.fromARGB(255, 0, 183, 255),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data!.docs;

          // Group by teamname
          final Map<String, List<QueryDocumentSnapshot>> groups = {};
          for (var doc in docs) {
            final teamname = (doc['teamname'] as String?) ?? '';
            if (teamname.isNotEmpty) {
              groups.putIfAbsent(teamname, () => []).add(doc);
            }
          }

          if (groups.isEmpty) {
            return const Center(child: Text('No teams found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final teamname = groups.keys.elementAt(index);
              final totalCount = groups[teamname]!.length;

              return Card(
                elevation: 3,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.group, color: Colors.indigo),
                  title: Text(
                    teamname,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  subtitle: Text(
                    'Items: $totalCount',
                    style: const TextStyle(fontSize: 13, color: subtitleColor),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamDetailPage(teamname: teamname),
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
