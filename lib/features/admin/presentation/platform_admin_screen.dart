import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PlatformAdminScreen extends StatefulWidget {
	const PlatformAdminScreen({super.key});
	@override
	State<PlatformAdminScreen> createState() => _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends State<PlatformAdminScreen> {
	bool? _isAdmin;
	int _adminsCount = 0;
	bool _loading = true;
	String? _error;
	String _selectedTab = 'dashboard';

	// Admin role types
	final Map<String, String> _adminRoles = {
		'super_admin': 'Super Admin',
		'admin': 'Admin',
		'moderator': 'Moderator',
		'support': 'Support Staff',
		'analyst': 'Data Analyst',
	};

	// Worker role types
	final Map<String, String> _workerRoles = {
		'driver': 'Driver',
		'delivery_agent': 'Delivery Agent',
		'service_provider': 'Service Provider',
		'emergency_responder': 'Emergency Responder',
		'customer_support': 'Customer Support',
		'dispatcher': 'Dispatcher',
		'quality_controller': 'Quality Controller',
		'finance_officer': 'Finance Officer',
	};

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) throw Exception('Not signed in');
			final admins = await FirebaseFirestore.instance.collection('_config').doc('admins').collection('users').get();
			final me = admins.docs.any((d) => d.id == uid);
			setState(() {
				_isAdmin = me;
				_adminsCount = admins.size;
				_loading = false;
				_error = null;
			});
		} catch (e) {
			// Fallback: check just my doc; mark adminsCount unknown (-1)
			try {
				final uid = FirebaseAuth.instance.currentUser?.uid;
				final myDoc = await FirebaseFirestore.instance.collection('_config').doc('admins').collection('users').doc(uid).get();
				setState(() {
					_isAdmin = myDoc.exists;
					_adminsCount = -1;
					_loading = false;
					_error = e.toString();
				});
			} catch (_) {
				setState(() {
					_isAdmin = false;
					_adminsCount = -1;
					_loading = false;
					_error = e.toString();
				});
			}
		}
	}

	Future<void> _claimAdmin() async {
		final uid = FirebaseAuth.instance.currentUser!.uid;
		final user = FirebaseAuth.instance.currentUser!;
		await FirebaseFirestore.instance.collection('_config').doc('admins').collection('users').doc(uid).set({
			'role': 'super_admin',
			'email': user.email,
			'displayName': user.displayName ?? 'Admin User',
			'createdAt': DateTime.now().toIso8601String(),
			'permissions': ['all'],
			'status': 'active',
		});
		if (mounted) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Super Admin role granted')));
			await _init();
		}
	}

	// Legacy method - kept for compatibility but not used in new UI
	Future<void> _promptEdit(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data, {required bool isUser}) async {
		// Implementation kept for legacy support
	}

	Future<void> _promptAddUser() async {
		final nameCtl = TextEditingController();
		final emailCtl = TextEditingController();
		final phoneCtl = TextEditingController();
		String selectedRole = 'user';
		
		final ok = await showDialog<bool>(
			context: context,
			builder: (c) => StatefulBuilder(
				builder: (context, setState) => AlertDialog(
					title: const Text('Add New User'),
					content: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Full Name')),
							TextField(controller: emailCtl, decoration: const InputDecoration(labelText: 'Email')),
							TextField(controller: phoneCtl, decoration: const InputDecoration(labelText: 'Phone Number')),
							const SizedBox(height: 16),
							DropdownButtonFormField<String>(
								value: selectedRole,
								items: const [
									DropdownMenuItem(value: 'user', child: Text('Regular User')),
									DropdownMenuItem(value: 'premium_user', child: Text('Premium User')),
									DropdownMenuItem(value: 'business_user', child: Text('Business User')),
								],
								decoration: const InputDecoration(labelText: 'User Type'),
								onChanged: (v) => setState(() => selectedRole = v ?? 'user'),
							),
						],
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
						FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Create')),
					],
				),
			),
		);
		
		if (ok == true) {
			try {
				await FirebaseFirestore.instance.collection('users').add({
					'name': nameCtl.text.trim(),
					'email': emailCtl.text.trim(),
					'phone': phoneCtl.text.trim(),
					'userType': selectedRole,
					'status': 'active',
					'createdAt': DateTime.now().toIso8601String(),
					'createdBy': FirebaseAuth.instance.currentUser?.uid,
				});
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ User created successfully')));
				}
			} catch (e) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to create user: $e')));
				}
			}
		}
	}

	Future<void> _assignWorkerRole(String userId, String userName) async {
		String selectedRole = 'driver';
		final departmentCtl = TextEditingController();
		final salaryCtl = TextEditingController();
		
		final ok = await showDialog<bool>(
			context: context,
			builder: (c) => StatefulBuilder(
				builder: (context, setState) => AlertDialog(
					title: Text('Assign Worker Role to $userName'),
					content: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							DropdownButtonFormField<String>(
								value: selectedRole,
								items: _workerRoles.entries.map((e) => 
									DropdownMenuItem(value: e.key, child: Text(e.value))
								).toList(),
								decoration: const InputDecoration(labelText: 'Worker Role'),
								onChanged: (v) => setState(() => selectedRole = v ?? 'driver'),
							),
							TextField(controller: departmentCtl, decoration: const InputDecoration(labelText: 'Department')),
							TextField(controller: salaryCtl, decoration: const InputDecoration(labelText: 'Monthly Salary'), keyboardType: TextInputType.number),
						],
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
						FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Assign Role')),
					],
				),
			),
		);
		
		if (ok == true) {
			try {
				await FirebaseFirestore.instance.collection('worker_profiles').doc(userId).set({
					'userId': userId,
					'role': selectedRole,
					'roleTitle': _workerRoles[selectedRole],
					'department': departmentCtl.text.trim(),
					'salary': double.tryParse(salaryCtl.text.trim()) ?? 0.0,
					'status': 'active',
					'assignedAt': DateTime.now().toIso8601String(),
					'assignedBy': FirebaseAuth.instance.currentUser?.uid,
					'permissions': _getDefaultPermissions(selectedRole),
				});
				
				// Update user document with worker role
				await FirebaseFirestore.instance.collection('users').doc(userId).update({
					'workerRole': selectedRole,
					'isWorker': true,
				});
				
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Worker role assigned successfully')));
				}
			} catch (e) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to assign role: $e')));
				}
			}
		}
	}
	
	Future<void> _assignAdminRole(String userId, String userName) async {
		String selectedRole = 'moderator';
		List<String> selectedPermissions = [];
		
		final availablePermissions = [
			'user_management', 'provider_management', 'financial_management',
			'system_config', 'analytics', 'support_tickets', 'content_moderation'
		];
		
		final ok = await showDialog<bool>(
			context: context,
			builder: (c) => StatefulBuilder(
				builder: (context, setState) => AlertDialog(
					title: Text('Assign Admin Role to $userName'),
					content: SizedBox(
						height: 400,
						width: 400,
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								DropdownButtonFormField<String>(
									value: selectedRole,
									items: _adminRoles.entries.map((e) => 
										DropdownMenuItem(value: e.key, child: Text(e.value))
									).toList(),
									decoration: const InputDecoration(labelText: 'Admin Role'),
									onChanged: (v) => setState(() => selectedRole = v ?? 'moderator'),
								),
								const SizedBox(height: 16),
								const Text('Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
								Expanded(
									child: ListView(
										children: availablePermissions.map((perm) => CheckboxListTile(
											title: Text(perm.replaceAll('_', ' ').toUpperCase()),
											value: selectedPermissions.contains(perm),
											onChanged: (checked) {
												setState(() {
													if (checked == true) {
														selectedPermissions.add(perm);
													} else {
														selectedPermissions.remove(perm);
													}
												});
											},
										)).toList(),
									),
								),
							],
						),
					),
					actions: [
						TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
						FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Assign Role')),
					],
				),
			),
		);
		
		if (ok == true) {
			try {
				await FirebaseFirestore.instance.collection('_config').doc('admins').collection('users').doc(userId).set({
					'role': selectedRole,
					'permissions': selectedPermissions,
					'status': 'active',
					'assignedAt': DateTime.now().toIso8601String(),
					'assignedBy': FirebaseAuth.instance.currentUser?.uid,
				});
				
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Admin role assigned successfully')));
				}
			} catch (e) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to assign admin role: $e')));
				}
			}
		}
	}
	
	List<String> _getDefaultPermissions(String role) {
		switch (role) {
			case 'driver':
				return ['accept_rides', 'update_location', 'complete_trips'];
			case 'delivery_agent':
				return ['accept_deliveries', 'update_status', 'collect_payment'];
			case 'service_provider':
				return ['accept_bookings', 'provide_service', 'collect_payment'];
			case 'emergency_responder':
				return ['accept_emergencies', 'update_status', 'provide_emergency_care'];
			case 'customer_support':
				return ['handle_tickets', 'chat_with_users', 'escalate_issues'];
			case 'dispatcher':
				return ['assign_jobs', 'monitor_operations', 'coordinate_teams'];
			case 'quality_controller':
				return ['review_services', 'audit_providers', 'generate_reports'];
			case 'finance_officer':
				return ['process_payments', 'handle_refunds', 'generate_financial_reports'];
			default:
				return [];
		}
	}

	@override
	Widget build(BuildContext context) {
		if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
		final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
		if ((_adminsCount == 0 || _adminsCount == -1) && _isAdmin != true) {
			return Scaffold(
				appBar: AppBar(title: const Text('Platform Admin')),
				body: Center(
					child: Column(mainAxisSize: MainAxisSize.min, children: [
						if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Note: $_error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
						Text('Your UID: $uid', style: const TextStyle(fontSize: 12, color: Colors.black54)),
						const SizedBox(height: 12),
						FilledButton(onPressed: _claimAdmin, child: const Text('Claim platform admin')),
					]),
				),
			);
		}
		if (_isAdmin != true) {
			return Scaffold(
				appBar: AppBar(title: const Text('Platform Admin')),
				body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
					if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Error: $_error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
					Text('Your UID: $uid', style: const TextStyle(fontSize: 12, color: Colors.black54)),
					const SizedBox(height: 12),
					const Text('Access denied. Contact a platform admin.'),
				])),
			);
		}
		return Scaffold(
			appBar: AppBar(
				title: const Text('Platform Admin'),
				backgroundColor: Colors.indigo,
				foregroundColor: Colors.white,
				actions: [
					IconButton(
						icon: const Icon(Icons.refresh),
						onPressed: _init,
					),
				],
			),
			body: Row(
				children: [
					// Sidebar
					Container(
						width: 250,
						color: Colors.indigo.shade50,
						child: ListView(
							children: [
								_buildSidebarItem('dashboard', Icons.dashboard, 'Dashboard'),
								_buildSidebarItem('users', Icons.people, 'User Management'),
								_buildSidebarItem('workers', Icons.work, 'Worker Management'),
								_buildSidebarItem('admins', Icons.admin_panel_settings, 'Admin Management'),
								_buildSidebarItem('providers', Icons.business, 'Provider Management'),
								_buildSidebarItem('analytics', Icons.analytics, 'Analytics'),
								_buildSidebarItem('system', Icons.settings, 'System Config'),
							],
						),
					),
					// Main content
					Expanded(
						child: _buildMainContent(),
					),
				],
			),
		);
	}
	
	Widget _buildSidebarItem(String id, IconData icon, String title) {
		final isSelected = _selectedTab == id;
		return ListTile(
			leading: Icon(icon, color: isSelected ? Colors.indigo : Colors.grey),
			title: Text(title, style: TextStyle(color: isSelected ? Colors.indigo : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
			selected: isSelected,
			selectedTileColor: Colors.indigo.shade100,
			onTap: () => setState(() => _selectedTab = id),
		);
	}
	
	Widget _buildMainContent() {
		switch (_selectedTab) {
			case 'dashboard':
				return _buildDashboard();
			case 'users':
				return _buildUserManagement();
			case 'workers':
				return _buildWorkerManagement();
			case 'admins':
				return _buildAdminManagement();
			case 'providers':
				return _buildProviderManagement();
			case 'analytics':
				return _buildAnalytics();
			case 'system':
				return _buildSystemConfig();
			default:
				return _buildDashboard();
		}
	}
	
	Widget _buildDashboard() {
		return ListView(
			padding: const EdgeInsets.all(16),
			children: [
				const Text('Platform Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
				const SizedBox(height: 16),
				
				// Quick stats
				Row(
					children: [
						_buildStatCard('Total Users', '0', Icons.people, Colors.blue),
						_buildStatCard('Active Workers', '0', Icons.work, Colors.green),
						_buildStatCard('Providers', '0', Icons.business, Colors.orange),
						_buildStatCard('Admin Staff', '$_adminsCount', Icons.admin_panel_settings, Colors.purple),
					],
				),
				
				const SizedBox(height: 24),
				
				// Quick actions
				const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
				const SizedBox(height: 16),
				
				Wrap(
					spacing: 16,
					runSpacing: 16,
					children: [
						_buildActionCard('Provider Applications', Icons.verified_user, () => context.push('/admin/applications')),
						_buildActionCard('Promos & Vouchers', Icons.card_giftcard, () => context.push('/admin/promos')),
						_buildActionCard('Emergency Config', Icons.emergency_share, () => context.push('/admin/emergency-config')),
						_buildActionCard('System Settings', Icons.settings, () => setState(() => _selectedTab = 'system')),
					],
				),
			],
		);
	}
	
	Widget _buildStatCard(String title, String value, IconData icon, Color color) {
		return Expanded(
			child: Card(
				color: color.withOpacity(0.1),
				child: Padding(
					padding: const EdgeInsets.all(16),
					child: Column(
						children: [
							Icon(icon, size: 32, color: color),
							const SizedBox(height: 8),
							Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
							Text(title, style: const TextStyle(fontSize: 12)),
						],
					),
				),
			),
		);
	}
	
	Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
		return SizedBox(
			width: 200,
			child: Card(
				child: InkWell(
					onTap: onTap,
					child: Padding(
						padding: const EdgeInsets.all(16),
						child: Column(
							children: [
								Icon(icon, size: 32),
								const SizedBox(height: 8),
								Text(title, textAlign: TextAlign.center),
							],
						),
					),
				),
			),
		);
	}
	
	Widget _buildUserManagement() {
		return ListView(
			padding: const EdgeInsets.all(16),
			children: [
				Row(
					children: [
						const Expanded(child: Text('User Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
						ElevatedButton.icon(
							onPressed: _promptAddUser,
							icon: const Icon(Icons.add),
							label: const Text('Add User'),
						),
					],
				),
				const SizedBox(height: 16),
				
				StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
					stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).limit(100).snapshots(),
					builder: (context, snap) {
						if (!snap.hasData) return const Center(child: CircularProgressIndicator());
						return SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							child: DataTable(
								columns: const [
									DataColumn(label: Text('Name')),
									DataColumn(label: Text('Email')),
									DataColumn(label: Text('Phone')),
									DataColumn(label: Text('Type')),
									DataColumn(label: Text('Status')),
									DataColumn(label: Text('Actions')),
								],
								rows: snap.data!.docs.map((d) {
									final data = d.data();
									return DataRow(
										cells: [
											DataCell(Text(data['name']?.toString() ?? 'N/A')),
											DataCell(Text(data['email']?.toString() ?? 'N/A')),
											DataCell(Text(data['phone']?.toString() ?? 'N/A')),
											DataCell(Text(data['userType']?.toString() ?? 'user')),
											DataCell(Text(data['status']?.toString() ?? 'active')),
											DataCell(
												Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														TextButton(
															onPressed: () => _assignWorkerRole(d.id, data['name']?.toString() ?? 'User'),
															child: const Text('Assign Worker Role'),
														),
														TextButton(
															onPressed: () => _assignAdminRole(d.id, data['name']?.toString() ?? 'User'),
															child: const Text('Assign Admin Role'),
														),
														TextButton(
															onPressed: () => d.reference.update({'status': data['status'] == 'active' ? 'disabled' : 'active'}),
															child: Text(data['status'] == 'active' ? 'Disable' : 'Enable'),
														),
													],
												),
											),
										],
									);
								}).toList(),
							),
						);
					},
				),
			],
		);
	}
	
	Widget _buildWorkerManagement() {
		return ListView(
			padding: const EdgeInsets.all(16),
			children: [
				const Text('Worker Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
				const SizedBox(height: 16),
				
				StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
					stream: FirebaseFirestore.instance.collection('worker_profiles').orderBy('assignedAt', descending: true).snapshots(),
					builder: (context, snap) {
						if (!snap.hasData) return const Center(child: CircularProgressIndicator());
						if (snap.data!.docs.isEmpty) return const Center(child: Text('No workers assigned yet'));
						
						return SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							child: DataTable(
								columns: const [
									DataColumn(label: Text('Worker ID')),
									DataColumn(label: Text('Role')),
									DataColumn(label: Text('Department')),
									DataColumn(label: Text('Salary')),
									DataColumn(label: Text('Status')),
									DataColumn(label: Text('Assigned Date')),
									DataColumn(label: Text('Actions')),
								],
								rows: snap.data!.docs.map((d) {
									final data = d.data();
									return DataRow(
										cells: [
											DataCell(Text(d.id.substring(0, 8))),
											DataCell(Text(data['roleTitle']?.toString() ?? 'N/A')),
											DataCell(Text(data['department']?.toString() ?? 'N/A')),
											DataCell(Text('₦${data['salary']?.toString() ?? '0'}')),
											DataCell(Text(data['status']?.toString() ?? 'active')),
											DataCell(Text(data['assignedAt']?.toString().substring(0, 10) ?? 'N/A')),
											DataCell(
												Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														TextButton(
															onPressed: () => d.reference.update({'status': data['status'] == 'active' ? 'suspended' : 'active'}),
															child: Text(data['status'] == 'active' ? 'Suspend' : 'Activate'),
														),
														TextButton(
															onPressed: () => d.reference.delete(),
															child: const Text('Remove', style: TextStyle(color: Colors.red)),
														),
													],
												),
											),
										],
									);
								}).toList(),
							),
						);
					},
				),
			],
		);
	}
	
	Widget _buildAdminManagement() {
		return ListView(
			padding: const EdgeInsets.all(16),
			children: [
				const Text('Admin Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
				const SizedBox(height: 16),
				
				StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
					stream: FirebaseFirestore.instance.collection('_config').doc('admins').collection('users').snapshots(),
					builder: (context, snap) {
						if (!snap.hasData) return const Center(child: CircularProgressIndicator());
						
						return SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							child: DataTable(
								columns: const [
									DataColumn(label: Text('Admin ID')),
									DataColumn(label: Text('Role')),
									DataColumn(label: Text('Permissions')),
									DataColumn(label: Text('Status')),
									DataColumn(label: Text('Assigned Date')),
									DataColumn(label: Text('Actions')),
								],
								rows: snap.data!.docs.map((d) {
									final data = d.data();
									return DataRow(
										cells: [
											DataCell(Text(d.id.substring(0, 8))),
											DataCell(Text(_adminRoles[data['role']] ?? data['role']?.toString() ?? 'N/A')),
											DataCell(Text((data['permissions'] as List?)?.join(', ') ?? 'None')),
											DataCell(Text(data['status']?.toString() ?? 'active')),
											DataCell(Text(data['assignedAt']?.toString().substring(0, 10) ?? data['createdAt']?.toString().substring(0, 10) ?? 'N/A')),
											DataCell(
												Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														TextButton(
															onPressed: () => d.reference.update({'status': data['status'] == 'active' ? 'suspended' : 'active'}),
															child: Text(data['status'] == 'active' ? 'Suspend' : 'Activate'),
														),
														if (data['role'] != 'super_admin')
															TextButton(
																onPressed: () => d.reference.delete(),
																child: const Text('Remove', style: TextStyle(color: Colors.red)),
															),
													],
												),
											),
										],
									);
								}).toList(),
							),
						);
					},
				),
			],
		);
	}
	
	Widget _buildProviderManagement() {
		return ListView(
			padding: const EdgeInsets.all(16),
			children: [
				const Text('Provider Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
				const SizedBox(height: 16),
				
				StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
					stream: FirebaseFirestore.instance.collection('provider_profiles').orderBy('createdAt', descending: true).limit(100).snapshots(),
					builder: (context, snap) {
						if (!snap.hasData) return const Center(child: CircularProgressIndicator());
						return SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							child: DataTable(
								columns: const [
									DataColumn(label: Text('Provider')),
									DataColumn(label: Text('Service')),
									DataColumn(label: Text('Category')),
									DataColumn(label: Text('Status')),
									DataColumn(label: Text('Rating')),
									DataColumn(label: Text('Actions')),
								],
								rows: snap.data!.docs.map((d) {
									final data = d.data();
									final meta = data['metadata'] as Map<String, dynamic>? ?? {};
									return DataRow(
										cells: [
											DataCell(Text(meta['title']?.toString() ?? d.id.substring(0, 8))),
											DataCell(Text(data['service']?.toString() ?? 'N/A')),
											DataCell(Text(data['subcategory']?.toString() ?? 'N/A')),
											DataCell(Text(data['status']?.toString() ?? 'N/A')),
											DataCell(Text('${data['rating']?.toString() ?? '0.0'} ⭐')),
											DataCell(
												Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														TextButton(
															onPressed: () => d.reference.update({'status': 'active'}),
															child: const Text('Approve'),
														),
														TextButton(
															onPressed: () => d.reference.update({'status': 'suspended'}),
															child: const Text('Suspend'),
														),
														TextButton(
															onPressed: () => d.reference.delete(),
															child: const Text('Delete', style: TextStyle(color: Colors.red)),
														),
													],
												),
											),
										],
									);
								}).toList(),
							),
						);
					},
				),
			],
		);
	}
	
	Widget _buildAnalytics() {
		return const Center(
			child: Text('Analytics Dashboard Coming Soon', style: TextStyle(fontSize: 18)),
		);
	}
	
	Widget _buildSystemConfig() {
		return ListView(
			padding: const EdgeInsets.all(16),
			children: [
				const Text('System Configuration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
				const SizedBox(height: 16),
				
				ListTile(
					leading: const Icon(Icons.verified_user),
					title: const Text('Provider Applications'),
					subtitle: const Text('Review and approve provider applications'),
					onTap: () => context.push('/admin/applications'),
				),
				
				ListTile(
					leading: const Icon(Icons.card_giftcard),
					title: const Text('Promos & Vouchers'),
					subtitle: const Text('Manage promotional campaigns'),
					onTap: () => context.push('/admin/promos'),
				),
				
				ListTile(
					leading: const Icon(Icons.emergency_share),
					title: const Text('Emergency Configuration'),
					subtitle: const Text('Configure emergency response settings'),
					onTap: () => context.push('/admin/emergency-config'),
				),
				
				ListTile(
					leading: const Icon(Icons.price_change),
					title: const Text('Pricing Dashboard'),
					subtitle: const Text('Manage service pricing'),
					onTap: () => context.push('/admin/pricing'),
				),
			],
		);
	}
}