import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../manager/assets_manager.dart';
import '../manager/loading_manager.dart';
import '../models/transfer_model.dart';
import '../providers/transfer_validation_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/empty_widget.dart';
import '../widgets/summary_chip.dart';
import '../widgets/transfer_card.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransfers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTransfers() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final transferProvider = Provider.of<TransferValidationProvider>(
      context,
      listen: false,
    );

    if (!userProvider.isLoggedIn || userProvider.user == null) {
      _showErrorSnackBar('Veuillez vous connecter pour accéder aux transferts');
      return;
    }

    final user = userProvider.user!;
    print('user Zone ${user.zone} && user Warehouse ${user.wareHouse}');
    await transferProvider.loadTransfers(
      zone: user.zone,
      warehouse: user.wareHouse,
    );

    if (transferProvider.lastErrorCode == 'AUTH_REQUIRED' ||
        transferProvider.lastErrorCode == '401') {
      await userProvider.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    if (transferProvider.hasError && mounted) {
      _showErrorSnackBar(transferProvider.error ?? 'Erreur inconnue');
    }
  }

  List<TransferModel> _applyFilters(List<TransferModel> list) {
    var filtered = list;
    if (_statusFilter != 'all') {
      filtered = filtered
          .where((t) => (t.status).toLowerCase() == _statusFilter)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (t) =>
                (t.reference).toLowerCase().contains(query) ||
                (t.destination).toLowerCase().contains(query) ||
                (t.origin).toLowerCase().contains(query),
          )
          .toList();
    }

    return filtered;
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onRefresh() async {
    await _loadTransfers();
  }

  void _onSummaryChipTap(String filterKey) {
    final filterMap = {
      'total': 'all',
      'completed': 'valide',
      'pending': 'brouillon',
    };
    final status = filterMap[filterKey] ?? 'all';
    context.read<TransferValidationProvider>().updateFilter(status);
    setState(() {
      _statusFilter = status;
      if (_currentPage != 1) {
        _currentPage = 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final transferProvider = Provider.of<TransferValidationProvider>(context);
    final allTransfers = transferProvider.allTransfers;
    final filteredTransfers = _applyFilters(allTransfers);
    final pending = allTransfers.where((t) => t.isPending).length;
    final completed = allTransfers.where((t) => t.isCompleted).length;
    final total = allTransfers.length;
    final filterStatus = transferProvider.filterStatus;
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: Scaffold(
        appBar: CustomAppBar(),
        body: LoadingManager(
          isLoading: transferProvider.isLoading,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.zero,
                      color: Colors.white,
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 1.8,
                        children: [
                          SummaryChip(
                            label: 'Total',
                            value: total.toString(),
                            color: Colors.blue,
                            icon: Icons.inventory_2,
                            unselectedBg: Colors.blueAccent,
                            isSelected: filterStatus == 'all',
                            onTap: () => _onSummaryChipTap('total'),
                          ),
                          SummaryChip(
                            label: 'completed',
                            value: completed.toString(),
                            color: Colors.green,
                            icon: Icons.check_circle,
                            unselectedBg: Colors.greenAccent,
                            isSelected: filterStatus == 'completed',
                            onTap: () => _onSummaryChipTap('completed'),
                          ),
                          SummaryChip(
                            label: 'En attente',
                            value: pending.toString(),
                            color: Colors.orange,
                            icon: Icons.pending,
                            unselectedBg: Colors.orangeAccent,
                            isSelected: filterStatus == 'pending',
                            onTap: () => _onSummaryChipTap('pending'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: CustomTextField(
                        textEditingController: _searchController,
                        hintText: 'Rechercher (réf, destination...)',
                        labelText: 'Rechercher',
                        isSearchTextField: true,
                      ),
                    ),
                    Expanded(
                      child: filteredTransfers.isEmpty
                          ? EmptyWidget(
                              imagePath: _searchController.text.isNotEmpty
                                  ? AssetsManager.emptySearch
                                  : AssetsManager.noData,
                              title: 'Aucun produit trouvé',
                              subtitle: _searchController.text.isNotEmpty
                                  ? 'Essayez de modifier votre recherche'
                                  : 'Aucun produit sur cette page',
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: filteredTransfers.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final transfer = filteredTransfers[index];
                                return TransferCard(transfer: transfer);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
