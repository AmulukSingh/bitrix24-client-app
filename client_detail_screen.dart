import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/deal.dart';
import '../services/bitrix_api_service.dart';
import 'deal_detail_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final Client client;

  const ClientDetailScreen({
    super.key,
    required this.client,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  List<Deal> _deals = [];
  List<Deal> _filteredDeals = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String _errorMessage = '';
  int _currentPage = 0;
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _deals = List.from(widget.client.deals);
    _filteredDeals = List.from(_deals);
    _loadMoreDeals();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreDeals();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredDeals = List.from(_deals);
      });
    } else {
      _performSearch(query);
    }
  }

  Future<void> _loadMoreDeals() async {
    if (_isLoadingMore || !_hasMoreData) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      List<Deal> newDeals = [];
      
      // If client has a valid company ID, fetch deals for that company
      if (widget.client.id.isNotEmpty && widget.client.id != widget.client.companyTitle) {
        newDeals = await BitrixApiService.fetchDealsForClient(
          widget.client.id,
          start: _currentPage * _pageSize,
          limit: _pageSize
        );
      } else {
        // If no company ID, search deals by company title
        final allDeals = await BitrixApiService.fetchDeals(
          start: _currentPage * _pageSize,
          limit: _pageSize
        );
        newDeals = allDeals.where((deal) => 
          deal.companyTitle?.toLowerCase() == widget.client.companyTitle.toLowerCase()
        ).toList();
      }

      if (newDeals.isNotEmpty) {
        // Remove duplicates and add new deals
        final existingIds = _deals.map((d) => d.id).toSet();
        final uniqueNewDeals = newDeals.where((d) => !existingIds.contains(d.id)).toList();
        
        setState(() {
          _deals.addAll(uniqueNewDeals);
          if (_searchController.text.isEmpty) {
            _filteredDeals = List.from(_deals);
          }
          _currentPage++;
          _hasMoreData = newDeals.length == _pageSize;
        });
      } else {
        setState(() {
          _hasMoreData = false;
        });
      }
    } catch (e) {
      print('Error loading more deals: $e');
      setState(() {
        _hasMoreData = false;
      });
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _performSearch(String query) {
    final filtered = _deals.where((deal) {
      final queryLower = query.toLowerCase();
      return deal.title.toLowerCase().contains(queryLower) ||
             (deal.companyTitle?.toLowerCase().contains(queryLower) ?? false);
    }).toList();
    
    setState(() {
      _filteredDeals = filtered;
    });
  }

  Future<void> _refreshDeals() async {
    setState(() {
      _currentPage = 0;
      _hasMoreData = true;
      _deals = List.from(widget.client.deals);
      _filteredDeals = List.from(_deals);
    });
    await _loadMoreDeals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client.companyTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeaderSection(context),
            
            // Contact Information
            _buildContactSection(),
            
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search deals...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            
            // Deals List
            Container(
              height: 400, // Fixed height for deals list
              child: _buildDealsSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.1),
            Theme.of(context).primaryColor.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.client.companyTitle,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.client.primaryContactPerson != 'No contact person')
            Text(
              'Contact: ${widget.client.primaryContactPerson}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                'Total Deals',
                widget.client.dealCount.toString(),
                Icons.business_center,
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Total Value',
                widget.client.formattedTotalOpportunity,
                Icons.attach_money,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard(
                'Won Deals',
                widget.client.wonDealsCount.toString(),
                Icons.check_circle,
                Colors.green,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Avg Deal Value',
                'USD ${widget.client.averageDealValue.toStringAsFixed(0)}',
                Icons.trending_up,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.phone,
                color: widget.client.hasPhone ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.client.hasPhone ? 'Phone Available' : 'No Phone',
                style: TextStyle(
                  color: widget.client.hasPhone ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.email,
                color: widget.client.hasEmail ? Colors.blue : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.client.hasEmail ? 'Email Available' : 'No Email',
                style: TextStyle(
                  color: widget.client.hasEmail ? Colors.blue : Colors.grey,
                ),
              ),
            ],
          ),
          if (widget.client.address != null && widget.client.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.client.address!,
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ],
          if (widget.client.website != null && widget.client.website!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.web,
                  color: Colors.purple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.client.website!,
                    style: const TextStyle(color: Colors.purple),
                  ),
                ),
              ],
            ),
          ],
          if (widget.client.industry != null && widget.client.industry!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.business,
                  color: Colors.teal,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Industry: ${widget.client.industry!}',
                  style: const TextStyle(color: Colors.teal),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDealsSection(BuildContext context) {
    if (_filteredDeals.isEmpty && !_isLoadingMore) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_center_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No deals found matching "${_searchController.text}"'
                  : 'No deals available for this client',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshDeals,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _filteredDeals.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredDeals.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final deal = _filteredDeals[index];
          return _buildDealCard(deal);
        },
      ),
    );
  }

  Widget _buildDealCard(Deal deal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DealDetailScreen(deal: deal),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deal.displayTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: deal.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      deal.statusDescription ?? deal.statusId,
                      style: TextStyle(
                        fontSize: 12,
                        color: deal.statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    deal.formattedOpportunity,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (deal.probability != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        deal.probabilityPercentage,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Created: ${deal.formattedDateCreate}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  if (deal.closeDate != null)
                    Row(
                      children: [
                        Icon(Icons.event, size: 14, color: Colors.orange[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Close: ${_formatDate(deal.closeDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[600],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
