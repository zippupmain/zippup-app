import 'package:flutter/material.dart';
import 'package:zippup/services/admin/admin_permissions_service.dart';

class AdminGuard extends StatefulWidget {
  final Widget child;
  final String? requiredPermission;
  final String? fallbackRoute;

  const AdminGuard({
    super.key,
    required this.child,
    this.requiredPermission,
    this.fallbackRoute,
  });

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  bool _isLoading = true;
  bool _hasAccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      bool hasAccess = false;

      if (widget.requiredPermission != null) {
        // Check specific permission
        hasAccess = await AdminPermissionsService.hasPermission(widget.requiredPermission!);
      } else {
        // Check if user is admin at all
        hasAccess = await AdminPermissionsService.isAdmin();
      }

      if (mounted) {
        setState(() {
          _hasAccess = hasAccess;
          _isLoading = false;
          _errorMessage = hasAccess ? null : 'Access denied. Required permission: ${widget.requiredPermission ?? 'admin'}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
          _errorMessage = 'Error checking permissions: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking permissions...'),
            ],
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.block,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'You do not have permission to access this page.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: widget.fallbackRoute != null
                          ? () => Navigator.of(context).pushReplacementNamed(widget.fallbackRoute!)
                          : () => Navigator.of(context).pushReplacementNamed('/'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}

class WorkerGuard extends StatefulWidget {
  final Widget child;
  final String? requiredPermission;
  final String? fallbackRoute;

  const WorkerGuard({
    super.key,
    required this.child,
    this.requiredPermission,
    this.fallbackRoute,
  });

  @override
  State<WorkerGuard> createState() => _WorkerGuardState();
}

class _WorkerGuardState extends State<WorkerGuard> {
  bool _isLoading = true;
  bool _hasAccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      bool hasAccess = false;

      if (widget.requiredPermission != null) {
        // Check specific worker permission
        hasAccess = await AdminPermissionsService.hasWorkerPermission(widget.requiredPermission!);
      } else {
        // Check if user is worker at all
        hasAccess = await AdminPermissionsService.isWorker();
      }

      if (mounted) {
        setState(() {
          _hasAccess = hasAccess;
          _isLoading = false;
          _errorMessage = hasAccess ? null : 'Access denied. Required permission: ${widget.requiredPermission ?? 'worker'}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
          _errorMessage = 'Error checking permissions: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking worker permissions...'),
            ],
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.work_off,
                  size: 64,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Worker Access Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'You need worker permissions to access this page.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: widget.fallbackRoute != null
                          ? () => Navigator.of(context).pushReplacementNamed(widget.fallbackRoute!)
                          : () => Navigator.of(context).pushReplacementNamed('/'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}