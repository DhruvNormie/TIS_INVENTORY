import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class TransactionListPage extends StatefulWidget {
  const TransactionListPage({Key? key}) : super(key: key);

  @override
  _TransactionListPageState createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  Map<String, String> _itemNameCache = {}; // itemId -> name mapping
  Map<String, String> _itemTeamCache = {}; // itemId -> team mapping
  bool _isExporting = false;

  String _filterType = 'all'; // 'all' | 'returnable' | 'nonreturnable' | 'overdue'
  bool _sortAscending = true;
  String _searchEmail = '';
  final TextEditingController _searchController = TextEditingController();
  String _searchComponent = '';
  final TextEditingController _componentSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItemNames();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _componentSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadItemNames() async {
    final snapshot = await FirebaseFirestore.instance.collection('items').get();
    setState(() {
      _itemNameCache = {
        for (var doc in snapshot.docs)
          doc.id: (doc['name'] ?? '').toString(),
      };
      _itemTeamCache = {
        for (var doc in snapshot.docs)
          doc.id: (doc['teamname'] ?? 'Unknown Team').toString(),
      };
    });
  }

  /// Converts the entire transaction (and its item entries) from non-returnable to returnable
  Future<void> _convertToReturnable(String transactionId) async {
    final docRef = FirebaseFirestore.instance.collection('transactions').doc(transactionId);

    try {
      final snapshot = await docRef.get();
      final data = snapshot.data() as Map<String, dynamic>;

      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
      final updatedItems = items.map((item) {
        final newItem = Map<String, dynamic>.from(item);
        newItem['type'] = 'returnable';
        newItem.remove('reason');
        return newItem;
      }).toList();

      await docRef.update({'type': 'returnable', 'items': updatedItems});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction converted to returnable')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error converting: $e')),
      );
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      // Request storage permission
      final permission = await Permission.storage.request();
      if (!permission.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission required for export')),
        );
        setState(() => _isExporting = false);
        return;
      }

      // Fetch all transactions
      final snapshot = await FirebaseFirestore.instance.collection('transactions').get();
      
      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions to export')),
        );
        setState(() => _isExporting = false);
        return;
      }

      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Transactions'];
      
      // Remove default sheet if it exists
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Define headers
      final headers = [
        'Transaction ID',
        'Type',
        'User Name',
        'User Email',
        'Transaction Date',
        'Status',
        'Return Requested',
        'Return Approved',
        'Component Name',
        'Component Team',
        'Quantity',
        'Is Overdue'
      ];

      // Add headers to sheet
      for (int i = 0; i < headers.length; i++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = headers[i] as CellValue?;
        cell.cellStyle = CellStyle(
          bold: true,
        //  backgroundColor: ExcelColor.fromHexString('#E3F2FD'),
         // fontColor: ExcelColor.fromHexString('#1976D2'),
        );
      }

      int rowIndex = 1;
      final dateFormatter = DateFormat('dd-MM-yyyy HH:mm');

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type']?.toString() ?? '';
        final userName = data['userName']?.toString() ?? '';
        final email = (data['userEmail'] ?? data['email'] ?? '').toString();
        final status = data['status']?.toString() ?? 'active';
        final ts = (data['timestamp'] ?? data['borrowedAt']) as Timestamp?;
        final reqTs = data['returnRequestedAt'] as Timestamp?;
        final apprTs = data['returnApprovedAt'] as Timestamp?;

        final transactionDate = ts != null ? dateFormatter.format(ts.toDate()) : '';
        final returnRequested = reqTs != null ? dateFormatter.format(reqTs.toDate()) : '';
        final returnApproved = apprTs != null ? dateFormatter.format(apprTs.toDate()) : '';

        // Determine if transaction is overdue
        final isReturnable = type.toLowerCase() == 'returnable';
        final isOverdue = ts != null && 
            isReturnable && 
            status != 'returned' && 
            DateTime.now().difference(ts.toDate()) > const Duration(hours: 24);

        // Get items list based on status
        final itemsList = status == 'returned' && data['returnRequest'] != null
            ? List<Map<String, dynamic>>.from(data['returnRequest']['items'] ?? [])
            : List<Map<String, dynamic>>.from(data['items'] ?? []);

        // If no items, add one row with transaction info
        if (itemsList.isEmpty) {
          final rowData = [
            doc.id,
            type,
            userName,
            email,
            transactionDate,
            status,
            returnRequested,
            returnApproved,
            'No items',
            '',
            '0',
            isOverdue ? 'Yes' : 'No',
          ];

          for (int i = 0; i < rowData.length; i++) {
            final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
            cell.value = rowData[i] as CellValue?;
            if (isOverdue) {
            //  cell.cellStyle = CellStyle(//fontColor: ExcelColor.fromHexString('#D32F2F'));
            }
          }
          rowIndex++;
        } else {
          // Add one row for each item
          for (var item in itemsList) {
            final itemId = item['itemId']?.toString() ?? '';
            final qty = (item['quantity'] ?? item['requestedQty'] ?? 0).toString();
            final componentName = _itemNameCache[itemId] ?? 'Unknown Item';
            final componentTeam = _itemTeamCache[itemId] ?? 'Unknown Team';

            final rowData = [
              doc.id,
              type,
              userName,
              email,
              transactionDate,
              status,
              returnRequested,
              returnApproved,
              componentName,
              componentTeam,
              qty,
              isOverdue ? 'Yes' : 'No',
            ];

            for (int i = 0; i < rowData.length; i++) {
              final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex));
              cell.value = rowData[i] as CellValue?;
              if (isOverdue) {
               // cell.cellStyle = CellStyle(fontColorHex: '#D32F2F');
              }
            }
            rowIndex++;
          }
        }
      }

      // Auto-size columns (approximate)
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15.0);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'transactions_export_$timestamp.xlsx';
      final filePath = '${directory.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      // Share the file
      await Share.shareXFiles([XFile(filePath)], text: 'Transaction Export');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported successfully: $fileName')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF4F6FD);
    const primaryColor = Color.fromARGB(255, 0, 183, 255);
    const textColor = Color(0xFF212121);
    const iconColor = Color(0xFF3949AB);

    final query = FirebaseFirestore.instance
        .collection('transactions')
        .orderBy('timestamp', descending: !_sortAscending);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('All Transactions'),
        centerTitle: true,
        elevation: 4,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by email',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchEmail = value.trim().toLowerCase()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _componentSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search by component name',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.widgets_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchComponent = value.trim().toLowerCase()),
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Export button
          IconButton(
            icon: _isExporting 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: 'Export to Excel',
            onPressed: _isExporting ? null : _exportToExcel,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filterType = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('All')),
              PopupMenuItem(value: 'returnable', child: Text('Returnable')),
              PopupMenuItem(value: 'nonreturnable', child: Text('Non-returnable')),
              PopupMenuItem(value: 'overdue', child: Text('Overdue')),
            ],
          ),
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            tooltip: 'Toggle sort order',
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No transactions found.'));
          }

          final items = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'doc': doc,
              'type': (data['type'] ?? '').toString().toLowerCase(),
              'timestamp': (data['timestamp'] ?? data['borrowedAt']) as Timestamp?,
              'reqTs': data['returnRequestedAt'] as Timestamp?,
              'apprTs': data['returnApprovedAt'] as Timestamp?,
              'email': (data['userEmail'] ?? data['email'] ?? '').toString().toLowerCase(),
            };
          }).where((item) {
            final type = item['type'] as String;
            final ts = item['timestamp'] as Timestamp?;
            final reqTs = item['reqTs'] as Timestamp?;
            final apprTs = item['apprTs'] as Timestamp?;

            // Transaction type filter
            bool typeMatch;
            switch (_filterType) {
              case 'returnable':
                typeMatch = type == 'returnable';
                break;
              case 'nonreturnable':
                typeMatch = type != 'returnable';
                break;
              case 'overdue':
                if (type != 'returnable' || ts == null) return false;
                final overdue = DateTime.now().difference(ts.toDate().toLocal()) > const Duration(hours: 24);
                typeMatch = overdue && reqTs == null && apprTs == null;
                break;
              default:
                typeMatch = true;
            }
            if (!typeMatch) return false;

            // Email search
            if (_searchEmail.isNotEmpty) {
              final email = item['email'] as String;
              if (!email.contains(_searchEmail)) return false;
            }

            // Component name search
            if (_searchComponent.isNotEmpty) {
              final data = (item['doc'] as QueryDocumentSnapshot).data() as Map<String, dynamic>;
              final itemsList = List<Map<String, dynamic>>.from(data['items'] ?? []);

              bool found = false;
              for (var comp in itemsList) {
                final itemId = (comp['itemId'] ?? '').toString();
                final itemName = (_itemNameCache[itemId] ?? '').toLowerCase();
                if (itemName.contains(_searchComponent)) {
                  found = true;
                  break;
                }
              }
              if (!found) return false;
            }

            return true;
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index]['doc'] as QueryDocumentSnapshot;
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type']?.toString() ?? '';
              final userName = data['userName']?.toString() ?? '';
              final email = (data['userEmail'] ?? data['email'] ?? '').toString();
              final ts = items[index]['timestamp'] as Timestamp?;
              final dateStr = ts != null ? DateFormat('dd-MM-yy HH:mm').format(ts.toDate().toLocal()) : 'Unknown';
              final reqDate = (items[index]['reqTs'] as Timestamp?)?.toDate().toLocal().let((d) => DateFormat('dd-MM-yy HH:mm').format(d));
              final apprDate = (items[index]['apprTs'] as Timestamp?)?.toDate().toLocal().let((d) => DateFormat('dd-MM-yy HH:mm').format(d));
              final status = data['status']?.toString().toLowerCase() ?? 'active';
              final itemsList = status == 'returned' && data['returnRequest'] != null
                  ? List<Map<String, dynamic>>.from(data['returnRequest']['items'] ?? [])
                  : List<Map<String, dynamic>>.from(data['items'] ?? []);

              final isReturnable = type.toLowerCase() == 'returnable';
              final isOverdue = ts != null &&
                  isReturnable &&
                  status != 'returned' &&
                  DateTime.now().difference(ts.toDate().toLocal()) > const Duration(hours: 24);

              return Opacity(
                opacity: status == 'pending_return' ? 0.6 : 1.0,
                child: Card(
                  color: status == 'pending_return' ? Colors.grey[200] : Colors.white,
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${type.isNotEmpty ? '${type[0].toUpperCase()}${type.substring(1)}' : 'Transaction'} by $userName",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isOverdue ? Colors.red : textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Email: $email', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'Date: $dateStr',
                          style: TextStyle(fontSize: 14, color: isOverdue ? Colors.red : textColor),
                        ),
                        if (reqDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Return requested: $reqDate',
                              style: const TextStyle(fontSize: 14, color: Colors.orange),
                            ),
                          ),
                        if (status == 'returned' && apprDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Return approved: $apprDate',
                              style: const TextStyle(fontSize: 14, color: Colors.green),
                            ),
                          ),
                        const Divider(height: 20),
                        ...itemsList.map((item) {
                          final itemId = item['itemId'] as String;
                          final qty = (item['quantity'] ?? item['requestedQty']) as int;
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('items').doc(itemId).get(),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const ListTile(title: Text('Loading item...'));
                              }
                              if (snap.hasError) {
                                return ListTile(
                                  title: Text('Error: ${snap.error}'),
                                  trailing: Text('Qty: $qty'),
                                );
                              }
                              if (!snap.hasData || !snap.data!.exists) {
                                return ListTile(
                                  title: const Text('Unknown item'),
                                  trailing: Text('Qty: $qty'),
                                );
                              }
                              final itemData = snap.data!.data() as Map<String, dynamic>;
                              final name = itemData['name'] as String? ?? 'Unnamed';
                              final teamName = itemData['teamname']?.toString() ?? 'Unknown Team';
                              return ListTile(
                                leading: const Icon(Icons.widgets_outlined, color: iconColor),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  'Team: $teamName',
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                                trailing: Text('Qty: $qty'),
                              );
                            },
                          );
                        }).toList(),
                        if (!isReturnable)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ElevatedButton(
                              onPressed: () => _convertToReturnable(doc.id),
                              child: const Text('Convert to Returnable'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Helper extension for nullable mapping
extension LetExtension<T> on T {
  R let<R>(R Function(T) op) => op(this);
}