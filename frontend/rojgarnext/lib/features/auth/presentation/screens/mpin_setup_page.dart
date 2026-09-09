// lib/features/auth/presentation/screens/mpin_setup_page.dart
// ✅ COMPLETE WORKING VERSION - On/Off Toggle with Input Boxes

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rojgarnext/core/storage/secure_storage.dart';
import 'package:rojgarnext/core/routes/app_routes.dart';
import 'package:rojgarnext/features/auth/presentation/controllers/auth_controller.dart';
import 'package:go_router/go_router.dart';

class MpinSetupPage extends StatefulWidget {
  final String email;

  const MpinSetupPage({
    super.key,
    required this.email,
  });

  @override
  State<MpinSetupPage> createState() => _MpinSetupPageState();
}

class _MpinSetupPageState extends State<MpinSetupPage> {
  // ============================================================
  // ✅ CONTROLLERS - 6 separate controllers for each digit
  // ============================================================
  final List<TextEditingController> _mpinControllers =
      List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> _confirmMpinControllers =
      List.generate(6, (_) => TextEditingController());

  // ============================================================
  // ✅ FOCUS NODES - For auto-tabbing between fields
  // ============================================================
  final List<FocusNode> _mpinFocusNodes =
      List.generate(6, (_) => FocusNode());
  final List<FocusNode> _confirmMpinFocusNodes =
      List.generate(6, (_) => FocusNode());

  // ============================================================
  // ✅ STATE VARIABLES
  // ============================================================
  bool _isSaving = false;
  String _errorMessage = '';
  bool _isDisposed = false;

  // ✅ Main state - Like Fingerprint Setup
  bool _isMpinEnabled = false;
  bool _isLoading = true;
  bool _hasExistingMpin = false;
  bool _showForm = false; // Controls input box visibility

  // PIN visibility
  bool _showMpin = false;
  bool _showConfirmMpin = false;

  // ============================================================
  // ✅ GETTERS
  // ============================================================
  String get _mpin => _mpinControllers.map((c) => c.text).join();
  String get _confirmMpin => _confirmMpinControllers.map((c) => c.text).join();
  bool get _isMpinComplete => _mpin.length == 6;
  bool get _isConfirmMpinComplete => _confirmMpin.length == 6;

  @override
  void initState() {
    super.initState();
    _checkMpinStatus();

    // Add listeners to update state on change
    for (int i = 0; i < 6; i++) {
      _mpinControllers[i].addListener(() {
        if (mounted) setState(() {});
      });
      _confirmMpinControllers[i].addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (var controller in _mpinControllers) {
      controller.dispose();
    }
    for (var controller in _confirmMpinControllers) {
      controller.dispose();
    }
    for (var node in _mpinFocusNodes) {
      node.dispose();
    }
    for (var node in _confirmMpinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // ============================================================
  // ✅ CHECK MPIN STATUS
  // ============================================================
  Future<void> _checkMpinStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final hasMpin = await SecureStorage.hasMpin();
      final isEnabled = await SecureStorage.isMpinEnabled();
      if (!mounted) return;
      setState(() {
        _hasExistingMpin = hasMpin;
        _isMpinEnabled = hasMpin && isEnabled;
        _showForm = false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMpinEnabled = false;
          _hasExistingMpin = false;
          _showForm = false;
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // ✅ TOGGLE MPIN - Like Fingerprint Setup
  // ============================================================
  Future<void> _toggleMpin(bool value) async {
    if (_isDisposed) return;

    // ============================================================
    // CASE 1: DISABLING MPIN - User explicitly turns OFF
    // ============================================================
    if (!value) {
      if (!_hasExistingMpin) {
        setState(() {
          _isMpinEnabled = false;
          _showForm = false;
          _clearAll();
        });
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Disable MPIN"),
          content: const Text(
            "Are you sure you want to disable MPIN login?\n\n"
            "You can enable it again later from settings.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Disable"),
            ),
          ],
        ),
      );

      if (confirm == true) {
        setState(() => _isLoading = true);
        try {
          await SecureStorage.setMpinEnabled(false);
          setState(() {
            _isMpinEnabled = false;
            _showForm = false;
            _clearAll();
            _hasExistingMpin = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("MPIN disabled successfully"),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to disable MPIN: $e"), backgroundColor: Colors.red),
            );
          }
        } finally {
          setState(() => _isLoading = false);
        }
      }
      return;
    }

    // ============================================================
    // CASE 2: ENABLING MPIN - User explicitly turns ON
    // ============================================================
    if (_hasExistingMpin) {
      setState(() => _isLoading = true);
      try {
        await SecureStorage.setMpinEnabled(true);
        setState(() {
          _isMpinEnabled = true;
          _showForm = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("MPIN enabled successfully"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to enable MPIN: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
      return;
    }

    // ============================================================
    // CASE 3: FIRST TIME SETUP - Show input form
    // ============================================================
    setState(() {
      _isMpinEnabled = true;
      _showForm = true; // ✅ THIS SHOWS THE INPUT BOXES
      _clearAll();
      _errorMessage = '';
    });

    // Auto-focus first field after form is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed && _showForm) {
        FocusScope.of(context).requestFocus(_mpinFocusNodes[0]);
      }
    });
  }

  void _clearAll() {
    if (_isDisposed) return;
    for (var c in _mpinControllers) c.clear();
    for (var c in _confirmMpinControllers) c.clear();
    setState(() {
      _errorMessage = '';
    });
  }

  // ============================================================
  // ✅ SAVE MPIN
  // ============================================================
  Future<void> _saveMpin() async {
    if (_isDisposed) return;

    final String mpin = _mpin;
    final String confirmMpin = _confirmMpin;

    setState(() => _errorMessage = '');

    if (mpin.length != 6) {
      setState(() => _errorMessage = 'Please enter 6-digit MPIN');
      return;
    }
    if (confirmMpin.length != 6) {
      setState(() => _errorMessage = 'Please confirm your 6-digit MPIN');
      return;
    }
    if (mpin != confirmMpin) {
      setState(() => _errorMessage = 'MPIN does not match. Please try again.');
      _clearAll();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed && _showForm) {
          FocusScope.of(context).requestFocus(_mpinFocusNodes[0]);
        }
      });
      return;
    }

    if (!mounted || _isDisposed) return;
    setState(() => _isSaving = true);

    try {
      final authController = Provider.of<AuthController>(context, listen: false);
      await authController.setupMpin(widget.email, mpin);
      await SecureStorage.saveMpin(mpin);
      await SecureStorage.setMpinEnabled(true);

      if (!mounted || _isDisposed) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("MPIN saved successfully! 🔒"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      setState(() {
        _hasExistingMpin = true;
        _isMpinEnabled = true;
        _showForm = false;
        _isSaving = false;
        _clearAll();
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && !_isDisposed) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          context.go(AppRoutes.userDashboard);
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save MPIN: ${e.toString()}"), backgroundColor: Colors.red),
        );
        setState(() => _errorMessage = 'Failed to save MPIN. Please try again.');
        setState(() => _isSaving = false);
        setState(() => _showForm = true);
      }
    }
  }

  // ============================================================
  // ✅ BUILD METHOD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading MPIN settings..."),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildToggleCard(),
                  const SizedBox(height: 20),
                  if (_errorMessage.isNotEmpty) _buildErrorWidget(),
                  if (_hasExistingMpin && _isMpinEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildRemoveButton(),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ HEADER
  // ============================================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(26), Colors.white.withAlpha(13)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withAlpha(51)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.purpleAccent, Colors.blueAccent],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent.withAlpha(77),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              _isMpinEnabled && _hasExistingMpin
                  ? Icons.lock_open
                  : _showForm
                      ? Icons.lock_outline
                      : Icons.lock_outline,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "MPIN Security",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isMpinEnabled && _hasExistingMpin
                ? "Your MPIN is currently enabled"
                : _showForm
                    ? "Set up a 6-digit PIN for quick & secure login"
                    : "Enable MPIN for faster and more secure login",
            style: TextStyle(
              color: Colors.white.withAlpha(204),
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.email,
              style: TextStyle(
                color: Colors.white.withAlpha(179),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ TOGGLE CARD - Like Fingerprint Setup
  // ============================================================
  Widget _buildToggleCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _isMpinEnabled ? Colors.green.withAlpha(26) : Colors.white.withAlpha(13),
            Colors.white.withAlpha(26),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isMpinEnabled
              ? Colors.green.withAlpha(102)
              : Colors.white.withAlpha(51),
        ),
      ),
      child: Column(
        children: [
          // ============================================================
          // ON/OFF TOGGLE ROW - Like Fingerprint Setup
          // ============================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isMpinEnabled
                          ? Colors.green.withAlpha(26)
                          : Colors.white.withAlpha(26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pin,
                      color: _isMpinEnabled ? Colors.green : Colors.white70,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "MPIN Login",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _isMpinEnabled ? Colors.green : Colors.white,
                        ),
                      ),
                      Text(
                        _isMpinEnabled && _hasExistingMpin
                            ? "Quick login with 6-digit PIN"
                            : _showForm
                                ? "Set your 6-digit PIN below"
                                : "Enable MPIN for faster login",
                        style: TextStyle(
                          fontSize: 12,
                          color: _isMpinEnabled
                              ? Colors.green.shade300
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // ✅ ON/OFF SWITCH - Like Fingerprint Setup
              Transform.scale(
                scale: 1.2,
                child: Switch(
                  value: _isMpinEnabled,
                  onChanged: _toggleMpin,
                  activeThumbColor: Colors.green,
                  activeTrackColor: Colors.green.shade200,
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.grey.shade800,
                ),
              ),
            ],
          ),

          // ============================================================
          // STATUS INDICATOR - Like Fingerprint Setup
          // ============================================================
          if (_isMpinEnabled && _hasExistingMpin)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "MPIN is enabled. You can use it for quick login.\n\n"
                        "✅ Your MPIN will NEVER be deleted on logout.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_showForm)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Set your MPIN below to enable MPIN login",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ============================================================
          // ✅ MPIN INPUT FORM - Shows when _showForm is true
          // ============================================================
          if (_showForm) ...[
            const SizedBox(height: 20),
            _buildDivider(),
            const SizedBox(height: 20),
            _buildMpinForm(),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // ✅ DIVIDER
  // ============================================================
  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withAlpha(26),
    );
  }

  // ============================================================
  // ✅ MPIN FORM - Input boxes for Android & Web
  // ============================================================
  Widget _buildMpinForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ============================================================
        // ENTER MPIN SECTION
        // ============================================================
        _buildSectionTitle("Enter MPIN", Icons.pin, Colors.blueAccent),
        const SizedBox(height: 12),
        _buildMpinInputRow(
          controllers: _mpinControllers,
          focusNodes: _mpinFocusNodes,
          isConfirm: false,
          onComplete: () {
            if (_mpin.length == 6) {
              FocusScope.of(context).requestFocus(_confirmMpinFocusNodes[0]);
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => setState(() => _showMpin = !_showMpin),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showMpin ? Icons.visibility : Icons.visibility_off,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showMpin ? "Hide" : "Show",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ============================================================
        // CONFIRM MPIN SECTION
        // ============================================================
        _buildSectionTitle("Confirm MPIN", Icons.verified, Colors.green),
        const SizedBox(height: 12),
        _buildMpinInputRow(
          controllers: _confirmMpinControllers,
          focusNodes: _confirmMpinFocusNodes,
          isConfirm: true,
          onComplete: () {
            if (_confirmMpin.length == 6 && _mpin.length == 6) {
              _saveMpin();
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => setState(() => _showConfirmMpin = !_showConfirmMpin),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showConfirmMpin ? Icons.visibility : Icons.visibility_off,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showConfirmMpin ? "Hide" : "Show",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ============================================================
        // SAVE BUTTON - Shows when both fields are complete
        // ============================================================
        if (_isMpinComplete && _isConfirmMpinComplete)
          _buildSaveButton(),

        if (!_isMpinComplete || !_isConfirmMpinComplete)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(26)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.white.withAlpha(128),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Enter and confirm 6-digit MPIN to save",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(128),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ============================================================
  // ✅ SECTION TITLE
  // ============================================================
  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withAlpha(179)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ✅ MPIN INPUT ROW - 6 Boxes with Auto-Tab
  // ============================================================
  Widget _buildMpinInputRow({
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required bool isConfirm,
    required VoidCallback onComplete,
  }) {
    final bool showPin = isConfirm ? _showConfirmMpin : _showMpin;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withAlpha(13),
            Colors.white.withAlpha(26),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(51)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          return _buildMpinBox(
            controller: controllers[index],
            focusNode: focusNodes[index],
            onChanged: (value) {
              // Auto-tab to next field
              if (value.length == 1 && index < 5) {
                FocusScope.of(context).requestFocus(focusNodes[index + 1]);
              }
              // Auto-tab to previous on delete
              if (value.isEmpty && index > 0) {
                FocusScope.of(context).requestFocus(focusNodes[index - 1]);
              }

              // Check if complete
              final currentValue = controllers.map((c) => c.text).join();
              if (currentValue.length == 6) {
                onComplete();
              }

              if (mounted) setState(() {});
            },
            onSubmitted: (_) {
              if (index < 5) {
                FocusScope.of(context).requestFocus(focusNodes[index + 1]);
              }
            },
            showPin: showPin,
            isFirst: index == 0,
          );
        }),
      ),
    );
  }

  // ============================================================
  // ✅ SINGLE MPIN BOX - Fully visible on Android & Web
  // ============================================================
  Widget _buildMpinBox({
    required TextEditingController controller,
    required FocusNode focusNode,
    required Function(String) onChanged,
    required Function(String) onSubmitted,
    required bool showPin,
    required bool isFirst,
  }) {
    return SizedBox(
      width: 46,
      height: 60,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: isFirst && _showForm,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: !showPin,
        obscuringCharacter: '●',
        enableIMEPersonalizedLearning: false,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: controller.text.isNotEmpty
              ? Colors.blueAccent.withAlpha(40)
              : Colors.white.withAlpha(20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: focusNode.hasFocus
                  ? Colors.blueAccent
                  : Colors.white.withAlpha(51),
              width: focusNode.hasFocus ? 2.5 : 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Colors.blueAccent,
              width: 2.5,
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }

  // ============================================================
  // ✅ SAVE BUTTON
  // ============================================================
  Widget _buildSaveButton() {
    final bool isEnabled = _isMpinComplete && _isConfirmMpinComplete && !_isSaving;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isEnabled ? _saveMpin : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isEnabled
                ? const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.grey.withAlpha(102),
                      Colors.grey.withAlpha(77)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(27),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: Colors.green.withAlpha(77),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, size: 22, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "Save MPIN",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ ERROR WIDGET
  // ============================================================
  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withAlpha(102)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = ''),
            child: const Icon(Icons.close, color: Colors.redAccent, size: 16),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ REMOVE BUTTON
  // ============================================================
  Widget _buildRemoveButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Remove MPIN"),
              content: const Text("Are you sure you want to remove your MPIN?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Remove"),
                ),
              ],
            ),
          );
          if (confirm == true) {
            setState(() => _isLoading = true);
            try {
              await SecureStorage.deleteMpin();
              await SecureStorage.setMpinEnabled(false);
              setState(() {
                _isMpinEnabled = false;
                _hasExistingMpin = false;
                _showForm = false;
                _clearAll();
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("MPIN removed successfully"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to remove MPIN: $e"), backgroundColor: Colors.red),
                );
              }
            } finally {
              setState(() => _isLoading = false);
            }
          }
        },
        icon: const Icon(Icons.delete_outline, size: 18),
        label: const Text(
          "Remove MPIN",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(23),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ ON WILL POP - Prevent accidental back navigation
  // ============================================================
  Future<bool> _onWillPop() async {
    if (_showForm && !_hasExistingMpin) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Cancel MPIN Setup"),
          content: const Text(
            "You haven't completed MPIN setup. Are you sure you want to leave?"
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Stay"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Leave"),
            ),
          ],
        ),
      );
      if (confirm == true) {
        setState(() {
          _isMpinEnabled = false;
          _showForm = false;
          _clearAll();
        });
        return true;
      }
      return false;
    }
    return true;
  }
}