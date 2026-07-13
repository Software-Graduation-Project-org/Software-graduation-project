import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/public_api_service.dart';
import '../../widgets/custom_text_field.dart';

class LabFinderScreen extends StatefulWidget {
  const LabFinderScreen({super.key});

  @override
  State<LabFinderScreen> createState() => _LabFinderScreenState();
}

class _LabFinderScreenState extends State<LabFinderScreen> {
  List<Map<String, dynamic>> _labs = [];
  List<Map<String, dynamic>> _filteredLabs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedLocation = 'All';
  final TextEditingController _searchController = TextEditingController();
  Map<String, List<Map<String, dynamic>>> _labTests = {}; // Cache for lab tests

  @override
  void initState() {
    super.initState();
    _loadLabs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLabs() async {
    try {
      final response = await PublicApiService.getAllLabs();
      if (mounted) {
        final labs = List<Map<String, dynamic>>.from(response['labs'] ?? []);

        // Load tests for each lab
        final Map<String, List<Map<String, dynamic>>> labTests = {};
        for (final lab in labs) {
          try {
            final testsResponse = await PublicApiService.getLabTests(lab['id']);
            labTests[lab['id']] = List<Map<String, dynamic>>.from(
              testsResponse['tests'] ?? [],
            );
          } catch (e) {
            // If loading tests fails, continue with empty list
            labTests[lab['id']] = [];
          }
        }

        if (mounted) {
          setState(() {
            _labs = labs;
            _filteredLabs = labs;
            _labTests = labTests;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading labs: $e')));
      }
    }
  }

  void _filterLabs() {
    setState(() {
      _filteredLabs = _labs.where((lab) {
        final matchesSearch =
            _searchQuery.isEmpty ||
            lab['lab_name'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            lab['owner_name'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );

        final matchesLocation =
            _selectedLocation == 'All' ||
            lab['address']?['city']?.toString().toLowerCase() ==
                _selectedLocation.toLowerCase();

        return matchesSearch && matchesLocation;
      }).toList();
    });
  }

  List<String> _getUniqueLocations() {
    // Return all Palestine cities instead of dynamic locations from data
    return [
      'All',
      'Gaza',
      'Rafah',
      'Khan Yunis',
      'Deir al-Balah',
      'Nuseirat',
      'Beit Lahia',
      'Jabalia',
      'Beit Hanoun',
      'Ramallah',
      'Al-Bireh',
      'Hebron',
      'Nablus',
      'Jerusalem',
      'Bethlehem',
      'Jenin',
      'Tulkarm',
      'Qalqilya',
      'Jericho',
      'Salfit',
      'Tubas',
    ];
  }

  String _formatOfficeHours(List<dynamic>? officeHours) {
    if (officeHours == null || officeHours.isEmpty) {
      return 'Hours not available';
    }

    final workingDays = officeHours
        .where((h) => h['is_closed'] != true)
        .toList();
    if (workingDays.isEmpty) return 'Closed';

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final fullDayNames = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    // Group by hours to show consolidated schedule
    final Map<String, List<String>> hoursToDays = {};

    for (final hours in workingDays) {
      final dayIndex = fullDayNames.indexOf(hours['day']);
      if (dayIndex == -1) continue;

      final openTime = hours['open_time'] ?? '';
      final closeTime = hours['close_time'] ?? '';
      final timeRange = openTime.isNotEmpty && closeTime.isNotEmpty
          ? '$openTime-$closeTime'
          : 'Hours not set';

      if (!hoursToDays.containsKey(timeRange)) {
        hoursToDays[timeRange] = [];
      }
      hoursToDays[timeRange]!.add(dayNames[dayIndex]);
    }

    // Format the working days and hours
    final formattedParts = <String>[];
    for (final entry in hoursToDays.entries) {
      final days = entry.value.join(', ');
      formattedParts.add('$days: ${entry.key}');
    }

    return formattedParts.join(' | ');
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _launchEmail(String email) async {
    final url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showTestsDialog(Map<String, dynamic> lab) {
    final tests = _labTests[lab['id']] ?? [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.science, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lab['lab_name'] ?? 'Lab Tests',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${tests.length} tests available',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Tests List
                Expanded(
                  child: tests.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No tests available'),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: tests.length,
                          itemBuilder: (context, index) {
                            final test = tests[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Test Details - Only show name and price
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            test['test_name'] ?? 'Unknown Test',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        if (test['price'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              '\$${test['price']}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Labs'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/'),
          tooltip: 'Return to Home',
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                CustomTextField(
                  controller: _searchController,
                  label: 'Search labs by name or owner',
                  prefixIcon: Icons.search,
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterLabs();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLocation,
                  decoration: const InputDecoration(
                    labelText: 'Filter by location',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  items: _getUniqueLocations().map((location) {
                    return DropdownMenuItem(
                      value: location,
                      child: Text(location),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _selectedLocation = value;
                      _filterLabs();
                    }
                  },
                ),
              ],
            ),
          ),

          // Results Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLabs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _labs.isEmpty
                              ? 'No labs available'
                              : 'No labs match your search',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _labs.isEmpty
                              ? 'Check back later for available laboratories'
                              : 'Try adjusting your search criteria',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredLabs.length,
                    itemBuilder: (context, index) {
                      final lab = _filteredLabs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Lab Name and Owner
                              Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lab['lab_name'] ?? 'Unknown Lab',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          'Owner: ${lab['owner_name'] ?? 'Unknown'}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Address
                              if (lab['address'] != null) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.grey[600],
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${lab['address']['street'] ?? ''}, ${lab['address']['city'] ?? ''}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],

                              // Office Hours
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: Colors.grey[600],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatOfficeHours(lab['office_hours']),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Contact Information
                              if ((lab['phone_number'] != null &&
                                      lab['phone_number']
                                          .toString()
                                          .isNotEmpty) ||
                                  (lab['email'] != null &&
                                      lab['email'].toString().isNotEmpty)) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.contact_phone,
                                      color: Colors.grey[600],
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (lab['phone_number'] != null &&
                                              lab['phone_number']
                                                  .toString()
                                                  .isNotEmpty)
                                            Text(
                                              'Phone: ${lab['phone_number']}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                          if (lab['email'] != null &&
                                              lab['email']
                                                  .toString()
                                                  .isNotEmpty)
                                            Text(
                                              'Email: ${lab['email']}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Available Tests Section
                              if (_labTests[lab['id']] != null &&
                                  _labTests[lab['id']]!.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.science,
                                      color: Colors.grey[600],
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_labTests[lab['id']]!.length} tests available',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => _showTestsDialog(lab),
                                      child: Text(
                                        'View All',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Show first few tests as examples with prices
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: _labTests[lab['id']]!
                                      .take(3)
                                      .map(
                                        (test) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                test['test_name'] ?? '',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                              if (test['price'] != null) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '\$${test['price']}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                if (_labTests[lab['id']]!.length > 3)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+${_labTests[lab['id']]!.length - 3} more tests',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey[600]),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                              ],

                              // Contact Buttons
                              Row(
                                children: [
                                  if (lab['phone_number'] != null &&
                                      lab['phone_number'].toString().isNotEmpty)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _launchPhone(lab['phone_number']),
                                        icon: const Icon(Icons.phone),
                                        label: const Text('Call'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (lab['phone_number'] != null &&
                                      lab['phone_number'].toString().isNotEmpty)
                                    const SizedBox(width: 8),
                                  if (lab['email'] != null &&
                                      lab['email'].toString().isNotEmpty)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _launchEmail(lab['email']),
                                        icon: const Icon(Icons.email),
                                        label: const Text('Email'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
